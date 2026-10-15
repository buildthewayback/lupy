// Lupy macOS shell — platform services: disk storage, Keychain, HTTP, notifications, clock.
// Keychain helper adapted from Coucou (MIT, (c) 2026 Louis Raillé), App/ClaudeService.swift.

import Foundation
import Security
import UserNotifications
import Darwin

// MARK: - Clock

final class SystemClock: LupyClock {
    func now() -> Timestamp { Timestamp(millis: Int64((Date().timeIntervalSince1970 * 1000).rounded())) }
}

extension Timestamp {
    var date: Date { Date(timeIntervalSince1970: Double(millis) / 1000) }
}

// MARK: - Disk storage (Application Support/Lupy/store)

enum DiskError: Error, CustomStringConvertible {
    case io(String)
    var description: String { switch self { case .io(let m): return m } }
}

final class DiskFileSystem: LupyFileSystem {
    let root: URL
    private let fm = FileManager.default

    init(root: URL) throws {
        self.root = root
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    private func url(_ path: String) throws -> URL {
        try PathRules.validate(path)
        return root.appendingPathComponent(path)
    }

    private func ensureParent(_ u: URL) throws {
        try fm.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

    func read(_ path: String) throws -> [UInt8]? {
        let u = try url(path)
        guard fm.fileExists(atPath: u.path) else { return nil }
        return [UInt8](try Data(contentsOf: u))
    }

    func writeAtomically(_ path: String, _ bytes: [UInt8]) throws {
        let u = try url(path)
        try ensureParent(u)
        let tmp = u.appendingPathExtension("tmp")
        guard fm.createFile(atPath: tmp.path, contents: nil) else { throw DiskError.io("cannot create \(tmp.lastPathComponent)") }
        let h = try FileHandle(forWritingTo: tmp)
        try h.write(contentsOf: Data(bytes))
        if fcntl(h.fileDescriptor, F_FULLFSYNC) != 0 { try h.synchronize() }
        try h.close()
        // rename(2) atomically replaces the destination on APFS/HFS+.
        if rename(tmp.path, u.path) != 0 { throw DiskError.io("rename failed (\(errno)) for \(path)") }
    }

    func append(_ path: String, _ bytes: [UInt8]) throws {
        let u = try url(path)
        try ensureParent(u)
        if !fm.fileExists(atPath: u.path) {
            guard fm.createFile(atPath: u.path, contents: nil) else { throw DiskError.io("cannot create \(path)") }
        }
        let h = try FileHandle(forWritingTo: u)
        defer { try? h.close() }
        _ = try h.seekToEnd()
        try h.write(contentsOf: Data(bytes))
        // F_FULLFSYNC flushes the drive cache too (plain fsync does not on macOS).
        if fcntl(h.fileDescriptor, F_FULLFSYNC) != 0 { try h.synchronize() }
    }

    func truncate(_ path: String, toLength length: Int) throws {
        let u = try url(path)
        let h = try FileHandle(forWritingTo: u)
        defer { try? h.close() }
        try h.truncate(atOffset: UInt64(length))
        if fcntl(h.fileDescriptor, F_FULLFSYNC) != 0 { try h.synchronize() }
    }

    func list(_ directory: String) throws -> [String] {
        let dir = directory.isEmpty ? root : try url(directory)
        guard fm.fileExists(atPath: dir.path) else { return [] }
        return try fm.contentsOfDirectory(atPath: dir.path).filter { !$0.hasPrefix(".") }.sorted()
    }

    func remove(_ path: String) throws {
        let u = try url(path)
        if fm.fileExists(atPath: u.path) { try fm.removeItem(at: u) }
    }

    func move(_ from: String, to: String) throws {
        let a = try url(from), b = try url(to)
        try ensureParent(b)
        if fm.fileExists(atPath: b.path) { try fm.removeItem(at: b) }
        try fm.moveItem(at: a, to: b)
    }

    func makeDirectory(_ path: String) throws {
        try fm.createDirectory(at: try url(path), withIntermediateDirectories: true)
    }

    func exists(_ path: String) -> Bool {
        guard let u = try? url(path) else { return false }
        return fm.fileExists(atPath: u.path)
    }

    /// Total bytes used by the store (diagnostics).
    func totalSize() -> Int {
        guard let e = fm.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total = 0
        for case let f as URL in e {
            total += (try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        }
        return total
    }
}

// MARK: - Keychain (secrets never leave it; never logged)

enum Keychain {
    static let service = "app.lupy.Lupy"

    @discardableResult
    static func save(_ account: String, _ value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        delete(account)
        // WhenUnlockedThisDeviceOnly: readable only while the Mac is unlocked, never synced or migrated.
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
            kSecAttrLabel as String: "Lupy: \(account)",
        ]
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func load(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Presence check without reading the secret (avoids unlock prompts).
    static func exists(_ account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        return SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess
    }

    @discardableResult
    static func delete(_ account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

// MARK: - HTTP (keys are inserted here, at send time)

struct HTTPResult {
    var status: Int
    var headers: [String: String]
    var body: [UInt8]
    var latencyMillis: Int64
}

enum HTTPExecutor {
    static let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 90
        c.timeoutIntervalForResource = 180
        c.waitsForConnectivity = false
        c.httpCookieStorage = nil
        c.urlCache = nil
        return URLSession(configuration: c)
    }()

    static func perform(_ spec: HTTPRequestSpec) async -> HTTPResult {
        guard let url = URL(string: spec.url), url.scheme == "https" else {
            return HTTPResult(status: 0, headers: [:], body: Array("Refusing non-HTTPS or invalid URL".utf8), latencyMillis: 0)
        }
        var req = URLRequest(url: url)
        req.httpMethod = spec.method
        req.timeoutInterval = spec.timeoutSeconds
        req.setValue("Lupy/0.1 (macOS)", forHTTPHeaderField: "User-Agent")
        for (k, v) in spec.headers { req.setValue(v, forHTTPHeaderField: k) }
        if let auth = spec.auth, let account = spec.keychainAccount {
            guard let key = Keychain.load(account), !key.isEmpty else {
                let msg = #"{"error":{"message":"No API key is stored in the Keychain for this service.","code":"invalid_api_key"}}"#
                return HTTPResult(status: 401, headers: [:], body: Array(msg.utf8), latencyMillis: 0)
            }
            req.setValue(auth.prefix + key, forHTTPHeaderField: auth.header)
        }
        if !spec.body.isEmpty { req.httpBody = Data(spec.body) }
        let start = Date()
        do {
            let (data, response) = try await session.data(for: req)
            let http = response as? HTTPURLResponse
            var headers: [String: String] = [:]
            if let fields = http?.allHeaderFields {
                for (k, v) in fields { headers[String(describing: k)] = String(describing: v) }
            }
            return HTTPResult(status: http?.statusCode ?? 0, headers: headers, body: [UInt8](data),
                              latencyMillis: Int64(Date().timeIntervalSince(start) * 1000))
        } catch {
            return HTTPResult(status: 0, headers: [:], body: Array(error.localizedDescription.utf8),
                              latencyMillis: Int64(Date().timeIntervalSince(start) * 1000))
        }
    }
}

// MARK: - Notifications

enum Notifier {
    static var enabled = true

    static func requestPermission() {
        guard enabled, Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func post(_ n: Notice) {
        guard enabled, Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = n.title
        content.body = n.body
        if n.severity == .urgent { content.sound = .default }
        let request = UNNotificationRequest(identifier: n.id.raw, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}

// MARK: - Memory measurement (diagnostics / self-test)

func residentMemoryMB() -> Double {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
    let kr: kern_return_t = withUnsafeMutablePointer(to: &info) { ptr in
        ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reb in
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), reb, &count)
        }
    }
    return kr == KERN_SUCCESS ? Double(info.resident_size) / 1_048_576 : -1
}
