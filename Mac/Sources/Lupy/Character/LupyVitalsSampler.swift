import AppKit
import Darwin
import Foundation
import IOKit.ps

//  What the Mac is actually doing.
//
//  The character is not decoration: this is the thing that moves him. Every reading
//  here is a real system signal, sampled the way Coucou does it — one timer every
//  three seconds, only while somebody can see the character, and a processor reading
//  is only believed on the second sample in a row (one spike must not make Lupy
//  panic).
//
//  Read cost is deliberately tiny: host_statistics for the processor, the system's
//  own thermal state, a memory-pressure source that pushes instead of polling, and
//  the internal battery through IOPS. No shell commands, no sudo, no private API.

@MainActor
final class LupyVitalsSampler: ObservableObject {
    /// Latest reading. Views observe this; the rig copies it into its mood target.
    @Published private(set) var vitals = LupyVitals()
    /// The two busiest apps since the previous sample, for the hover line.
    @Published private(set) var topProcesses: [String] = []

    private var timer: Timer?
    private var pressureSource: DispatchSourceMemoryPressure?
    private var lastTicks: (busy: UInt64, total: UInt64)?
    private var lastProcessTimes: [pid_t: UInt64] = [:]
    /// Consecutive samples above the busy threshold.
    private(set) var busyStreak = 0

    var isRunning: Bool { timer != nil }

    func start() {
        guard timer == nil else { return }
        sample()                                   // first reading immediately
        let timer = Timer(timeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        observeMemoryPressure()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        pressureSource?.cancel()
        pressureSource = nil
        lastTicks = nil
        busyStreak = 0
    }

    // MARK: sampling

    private func sample() {
        var next = vitals

        if let ticks = Self.cpuTicks() {
            if let last = lastTicks, ticks.total > last.total {
                let busyDelta = Double(ticks.busy &- last.busy)
                let totalDelta = Double(ticks.total &- last.total)
                if totalDelta > 0 {
                    next.cpu = min(1, max(0, busyDelta / totalDelta))
                }
            }
            lastTicks = ticks
        }

        next.thermal = Self.thermalLevel(ProcessInfo.processInfo.thermalState)
        if let battery = Self.readBattery() {
            next.batteryPercent = battery.percent
            next.onPower = battery.onPower
        }
        // memoryPressure is pushed by the source; keep whatever it last set.

        busyStreak = next.cpu >= 0.8 ? busyStreak + 1 : 0

        // Only look for the busiest apps when the processor is actually pinned: this is
        // the most expensive reading, and a quiet Mac does not need it.
        if busyStreak >= 2 {
            topProcesses = topProcessNames()
        } else {
            lastProcessTimes = [:]
            topProcesses = []
        }
        vitals = next
    }

    /// Memory pressure pushes instead of polling, so nothing is read while nothing
    /// changes. The mask includes `.normal` so the mood can come back down again.
    private func observeMemoryPressure() {
        guard pressureSource == nil else { return }
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.normal, .warning, .critical], queue: .main
        )
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self, let event = self.pressureSource?.data else { return }
                var next = self.vitals
                next.memoryPressure = event.contains(.critical) ? 2
                    : (event.contains(.warning) ? 1 : 0)
                self.vitals = next
            }
        }
        source.resume()
        pressureSource = source
    }

    // MARK: the machine's own numbers

    /// Busy and total processor ticks over every core since boot.
    private static func cpuTicks() -> (busy: UInt64, total: UInt64)? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let user = UInt64(info.cpu_ticks.0), system = UInt64(info.cpu_ticks.1)
        let idle = UInt64(info.cpu_ticks.2), nice = UInt64(info.cpu_ticks.3)
        return (user + system + nice, user + system + idle + nice)
    }

    private static func thermalLevel(_ state: ProcessInfo.ThermalState) -> Int {
        switch state {
        case .nominal: return 0
        case .fair: return 1
        case .serious: return 2
        case .critical: return 3
        @unknown default: return 0
        }
    }

    /// The internal battery, or nil on a Mac without one.
    private static func readBattery() -> (percent: Int, onPower: Bool)? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() else { return nil }
        for source in list as Array {
            guard let desc = IOPSGetPowerSourceDescription(blob, source as CFTypeRef)?
                    .takeUnretainedValue() as? [String: Any],
                  desc[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = desc[kIOPSCurrentCapacityKey] as? Int,
                  let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0
            else { continue }
            let onPower = desc[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            return (Int((Double(current) / Double(max) * 100).rounded()), onPower)
        }
        return nil
    }

    /// The apps using the processor the most since the last reading.
    private func topProcessNames() -> [String] {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(estimate) + 64)
        let found = pids.withUnsafeMutableBytes {
            proc_listallpids($0.baseAddress, Int32($0.count))
        }
        guard found > 0 else { return [] }

        var times: [pid_t: UInt64] = [:]
        var deltas: [(pid: pid_t, delta: UInt64)] = []
        let own = getpid()
        for pid in pids.prefix(Int(found)) where pid > 0 && pid != own {
            var usage = rusage_info_v2()
            let ok = withUnsafeMutablePointer(to: &usage) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_V2, $0)
                }
            }
            guard ok == 0 else { continue }
            let total = usage.ri_user_time + usage.ri_system_time
            times[pid] = total
            if let before = lastProcessTimes[pid], total > before {
                deltas.append((pid, total - before))
            }
        }
        lastProcessTimes = times

        var names: [String] = []
        for entry in deltas.sorted(by: { $0.delta > $1.delta }) {
            let name = Self.displayName(pid: entry.pid)
            if !name.isEmpty, !names.contains(name) { names.append(name) }
            if names.count == 2 { break }
        }
        return names
    }

    private static func displayName(pid: pid_t) -> String {
        var name: String
        if let app = NSRunningApplication(processIdentifier: pid), let local = app.localizedName {
            name = local
        } else {
            var buffer = [CChar](repeating: 0, count: 256)
            proc_name(pid, &buffer, 256)
            name = String(cString: buffer)
        }
        if let range = name.range(of: " Helper") { name = String(name[..<range.lowerBound]) }
        return name
    }
}
