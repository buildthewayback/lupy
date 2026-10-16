// LupyCore — time, identifiers, hashing. Pure Swift, deterministic when injected.

// MARK: - Timestamp

/// Milliseconds since 1970-01-01T00:00:00Z (UTC). Time zones are a display concern of the shell.
public struct Timestamp: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
    public var millis: Int64

    public init(millis: Int64) { self.millis = millis }

    public static func < (a: Timestamp, b: Timestamp) -> Bool { a.millis < b.millis }

    public func adding(_ d: Millis) -> Timestamp { Timestamp(millis: millis + d.value) }
    public func since(_ other: Timestamp) -> Millis { Millis(millis - other.millis) }

    public var description: String { iso8601 }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self), let t = Timestamp(iso8601: s) { self = t; return }
        self.millis = try c.decode(Int64.self)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(iso8601)
    }

    // MARK: ISO-8601 (UTC, millisecond precision) — civil-from-days algorithm (H. Hinnant).

    public struct Civil: Equatable, Sendable {
        public var year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, millisecond: Int
        /// 0 = Sunday … 6 = Saturday
        public var weekday: Int
    }

    public var civil: Civil {
        let ms = Int64(millis)
        var days = ms >= 0 ? ms / 86_400_000 : (ms - 86_399_999) / 86_400_000
        let msOfDay = ms - days * 86_400_000
        let weekday = Int(((days % 7) + 11) % 7) // 1970-01-01 was a Thursday (4)
        days += 719_468
        let era = (days >= 0 ? days : days - 146_096) / 146_097
        let doe = days - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        let year = Int(m <= 2 ? y + 1 : y)
        return Civil(year: year, month: Int(m), day: Int(d),
                     hour: Int(msOfDay / 3_600_000), minute: Int((msOfDay / 60_000) % 60),
                     second: Int((msOfDay / 1000) % 60), millisecond: Int(msOfDay % 1000),
                     weekday: weekday)
    }

    public static func daysFromCivil(year: Int, month: Int, day: Int) -> Int64 {
        let y = Int64(month <= 2 ? year - 1 : year)
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = Int64(month > 2 ? month - 3 : month + 9)
        let doy = (153 * mp + 2) / 5 + Int64(day) - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    public init(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0, second: Int = 0, millisecond: Int = 0) {
        let days = Timestamp.daysFromCivil(year: year, month: month, day: day)
        millis = days * 86_400_000 + Int64(hour) * 3_600_000 + Int64(minute) * 60_000 + Int64(second) * 1000 + Int64(millisecond)
    }

    public var iso8601: String {
        let c = civil
        return "\(pad(c.year, 4))-\(pad(c.month, 2))-\(pad(c.day, 2))T\(pad(c.hour, 2)):\(pad(c.minute, 2)):\(pad(c.second, 2)).\(pad(c.millisecond, 3))Z"
    }

    /// `YYYY-MM-DD`
    public var dateOnly: String {
        let c = civil
        return "\(pad(c.year, 4))-\(pad(c.month, 2))-\(pad(c.day, 2))"
    }

    /// Accepts `YYYY-MM-DD`, `YYYY-MM-DDTHH:MM[:SS[.fff]]` with `Z` or `±HH:MM` offset (no offset = UTC).
    public init?(iso8601 s: String) {
        let chars = Array(s.utf8)
        func num(_ from: Int, _ len: Int) -> Int? {
            guard from + len <= chars.count else { return nil }
            var v = 0
            for k in from..<(from + len) {
                let c = chars[k]
                guard c >= 0x30 && c <= 0x39 else { return nil }
                v = v * 10 + Int(c - 0x30)
            }
            return v
        }
        guard let y = num(0, 4), chars.count >= 10, chars[4] == 0x2D, let mo = num(5, 2), chars[7] == 0x2D, let d = num(8, 2),
              (1...12).contains(mo), (1...31).contains(d) else { return nil }
        var h = 0, mi = 0, se = 0, ms = 0, offsetMin = 0
        var i = 10
        if i < chars.count {
            guard chars[i] == 0x54 || chars[i] == 0x20, let hh = num(i + 1, 2), chars.count > i + 3, chars[i + 3] == 0x3A, let mm = num(i + 4, 2) else { return nil }
            h = hh; mi = mm; i += 6
            if i < chars.count, chars[i] == 0x3A {
                guard let ss = num(i + 1, 2) else { return nil }
                se = ss; i += 3
                if i < chars.count, chars[i] == 0x2E {
                    i += 1
                    var digits = 0, frac = 0
                    while i < chars.count, chars[i] >= 0x30 && chars[i] <= 0x39 {
                        if digits < 3 { frac = frac * 10 + Int(chars[i] - 0x30); digits += 1 }
                        i += 1
                    }
                    guard digits > 0 else { return nil }
                    while digits < 3 { frac *= 10; digits += 1 }
                    ms = frac
                }
            }
            if i < chars.count {
                if chars[i] == 0x5A { i += 1 }
                else if chars[i] == 0x2B || chars[i] == 0x2D {
                    let sign = chars[i] == 0x2B ? 1 : -1
                    guard let oh = num(i + 1, 2) else { return nil }
                    var om = 0
                    if i + 3 < chars.count, chars[i + 3] == 0x3A { guard let v = num(i + 4, 2) else { return nil }; om = v; i += 6 }
                    else if let v = num(i + 3, 2) { om = v; i += 5 }
                    else { i += 3 }
                    offsetMin = sign * (oh * 60 + om)
                } else { return nil }
            }
            guard i == chars.count, h < 24, mi < 60, se < 61 else { return nil }
        }
        self.init(year: y, month: mo, day: d, hour: h, minute: mi, second: min(se, 59), millisecond: ms)
        millis -= Int64(offsetMin) * 60_000
    }

    /// Start of the UTC day containing this timestamp, shifted by a UTC offset in minutes (local day boundary).
    public func startOfDay(utcOffsetMinutes: Int = 0) -> Timestamp {
        let shifted = millis + Int64(utcOffsetMinutes) * 60_000
        let day = shifted >= 0 ? shifted / 86_400_000 : (shifted - 86_399_999) / 86_400_000
        return Timestamp(millis: day * 86_400_000 - Int64(utcOffsetMinutes) * 60_000)
    }

    /// Key for monthly budgets: "YYYY-MM" in the given local offset.
    public func monthKey(utcOffsetMinutes: Int = 0) -> String {
        let c = Timestamp(millis: millis + Int64(utcOffsetMinutes) * 60_000).civil
        return "\(pad(c.year, 4))-\(pad(c.month, 2))"
    }

    public func dayKey(utcOffsetMinutes: Int = 0) -> String {
        Timestamp(millis: millis + Int64(utcOffsetMinutes) * 60_000).dateOnly
    }
}

@inline(__always) func pad(_ v: Int, _ width: Int) -> String {
    let s = String(abs(v))
    let p = s.count < width ? String(repeating: "0", count: width - s.count) + s : s
    return v < 0 ? "-" + p : p
}

/// A signed duration in milliseconds.
public struct Millis: Codable, Hashable, Comparable, Sendable {
    public var value: Int64
    public init(_ value: Int64) { self.value = value }
    public static func < (a: Millis, b: Millis) -> Bool { a.value < b.value }
    public static func seconds(_ s: Int64) -> Millis { Millis(s * 1000) }
    public static func minutes(_ m: Int64) -> Millis { Millis(m * 60_000) }
    public static func hours(_ h: Int64) -> Millis { Millis(h * 3_600_000) }
    public static func days(_ d: Int64) -> Millis { Millis(d * 86_400_000) }
    public var hours: Double { Double(value) / 3_600_000 }
    public var minutes: Double { Double(value) / 60_000 }
    public static func + (a: Millis, b: Millis) -> Millis { Millis(a.value + b.value) }
    public static func * (a: Millis, k: Int64) -> Millis { Millis(a.value * k) }

    public init(from decoder: Decoder) throws { value = try decoder.singleValueContainer().decode(Int64.self) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(value) }
}

// MARK: - Clock

public protocol LupyClock: AnyObject {
    func now() -> Timestamp
}

/// Test clock: time only moves when told to.
public final class ManualClock: LupyClock {
    public var current: Timestamp
    public init(_ start: Timestamp) { current = start }
    public func now() -> Timestamp { current }
    public func advance(_ d: Millis) { current = current.adding(d) }
}

// MARK: - Identifiers

/// Opaque, sortable-ish identifier like `tsk_k2f9...`. Never reused.
public struct LupyID: Codable, Hashable, Comparable, Sendable, CustomStringConvertible, ExpressibleByStringLiteral {
    public let raw: String
    public init(_ raw: String) { self.raw = raw }
    public init(stringLiteral value: String) { raw = value }
    public var description: String { raw }
    public static func < (a: LupyID, b: LupyID) -> Bool { a.raw < b.raw }

    public init(from decoder: Decoder) throws { raw = try decoder.singleValueContainer().decode(String.self) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(raw) }

    public var prefix: String { raw.split(separator: "_").first.map(String.init) ?? "" }
}

public protocol IDGenerator: AnyObject {
    func next(_ prefix: String) -> LupyID
}

/// Production generator: time-ordered prefix + 64 random bits (base32, lowercase).
public final class RandomIDGenerator: IDGenerator {
    private let clock: LupyClock
    private var rng = SystemRandomNumberGenerator()
    public init(clock: LupyClock) { self.clock = clock }
    public func next(_ prefix: String) -> LupyID {
        let t = UInt64(max(0, clock.now().millis))
        return LupyID("\(prefix)_\(base32(t, digits: 9))\(base32(rng.next(), digits: 13))")
    }
}

/// Test generator: `tsk_0001`, `tsk_0002`, … per prefix.
public final class SequentialIDGenerator: IDGenerator {
    private var counters: [String: Int] = [:]
    public init() {}
    public func next(_ prefix: String) -> LupyID {
        let n = (counters[prefix] ?? 0) + 1
        counters[prefix] = n
        return LupyID("\(prefix)_\(pad(n, 4))")
    }
}

func base32(_ v: UInt64, digits: Int) -> String {
    let alphabet = Array("0123456789abcdefghjkmnpqrstvwxyz") // Crockford-style, no i l o u
    var out: [Character] = []
    var x = v
    for _ in 0..<digits { out.append(alphabet[Int(x & 31)]); x >>= 5 }
    return String(out.reversed())
}

// MARK: - Hashing

public enum FNV1a {
    public static func hash64(_ bytes: [UInt8]) -> UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in bytes { h ^= UInt64(b); h = h &* 0x0000_0100_0000_01B3 }
        return h
    }
    public static func hex64(_ s: String) -> String { hex(hash64(Array(s.utf8))) }
    static func hex(_ v: UInt64) -> String {
        let digits = Array("0123456789abcdef")
        var out = ""
        for shift in stride(from: 60, through: 0, by: -4) { out.append(digits[Int((v >> UInt64(shift)) & 0xF)]) }
        return out
    }
}

/// FIPS 180-4 SHA-256, used for journal hash chains, backup manifests and artifact fingerprints.
public enum SHA256Digest {
    private static let k: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ]

    public static func digest(_ message: [UInt8]) -> [UInt8] {
        var h: [UInt32] = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]
        var msg = message
        let bitLen = UInt64(message.count) &* 8
        msg.append(0x80)
        while msg.count % 64 != 56 { msg.append(0) }
        for i in (0..<8).reversed() { msg.append(UInt8((bitLen >> (UInt64(i) * 8)) & 0xFF)) }
        var w = [UInt32](repeating: 0, count: 64)
        var chunk = 0
        while chunk < msg.count {
            for i in 0..<16 {
                let b = chunk + i * 4
                w[i] = UInt32(msg[b]) << 24 | UInt32(msg[b + 1]) << 16 | UInt32(msg[b + 2]) << 8 | UInt32(msg[b + 3])
            }
            for i in 16..<64 {
                let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
                let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
                w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
            }
            var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7]
            for i in 0..<64 {
                let S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
                let ch = (e & f) ^ (~e & g)
                let t1 = hh &+ S1 &+ ch &+ k[i] &+ w[i]
                let S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
                let maj = (a & b) ^ (a & c) ^ (b & c)
                let t2 = S0 &+ maj
                hh = g; g = f; f = e; e = d &+ t1; d = c; c = b; b = a; a = t1 &+ t2
            }
            h[0] = h[0] &+ a; h[1] = h[1] &+ b; h[2] = h[2] &+ c; h[3] = h[3] &+ d
            h[4] = h[4] &+ e; h[5] = h[5] &+ f; h[6] = h[6] &+ g; h[7] = h[7] &+ hh
            chunk += 64
        }
        var out: [UInt8] = []
        out.reserveCapacity(32)
        for v in h { out += [UInt8(v >> 24), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)] }
        return out
    }

    public static func hex(_ message: [UInt8]) -> String { toHex(digest(message)) }
    public static func hex(_ s: String) -> String { hex(Array(s.utf8)) }

    @inline(__always) private static func rotr(_ x: UInt32, _ n: UInt32) -> UInt32 { (x >> n) | (x << (32 - n)) }
}

public func toHex(_ bytes: [UInt8]) -> String {
    let digits = Array("0123456789abcdef")
    var s = ""
    s.reserveCapacity(bytes.count * 2)
    for b in bytes { s.append(digits[Int(b >> 4)]); s.append(digits[Int(b & 0xF)]) }
    return s
}

// MARK: - Deterministic RNG (for jitter in tests and reproducible backoff)

public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Small text helpers (no Foundation)

public enum TextUtil {
    public static func trimmed(_ s: String) -> String {
        var scalars = Substring(s)
        while let f = scalars.first, f.isWhitespace { scalars.removeFirst() }
        while let l = scalars.last, l.isWhitespace { scalars.removeLast() }
        return String(scalars)
    }

    /// Lowercased words (letters/digits), for keyword search and heuristics.
    public static func words(_ s: String) -> [String] {
        var out: [String] = []
        var cur = ""
        for ch in s.lowercased() {
            if ch.isLetter || ch.isNumber { cur.append(ch) }
            else if !cur.isEmpty { out.append(cur); cur = "" }
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }

    /// Truncate to at most `max` characters, adding an ellipsis.
    public static func truncate(_ s: String, _ max: Int) -> String {
        guard s.count > max else { return s }
        return String(s.prefix(Swift.max(0, max - 1))) + "…"
    }

    public static func slug(_ s: String) -> String {
        let w = words(s)
        return w.isEmpty ? "untitled" : w.joined(separator: "-")
    }

    public static func formatCents(_ cents: Double) -> String {
        let dollars = cents / 100
        if dollars < 1 && dollars > 0 { return "$" + fixed(dollars, 3) }
        return "$" + fixed(dollars, 2)
    }

    /// Fixed-point decimal formatting without Foundation.
    public static func fixed(_ v: Double, _ places: Int) -> String {
        guard v.isFinite else { return "0" }
        var mult = 1.0
        for _ in 0..<places { mult *= 10 }
        let scaled = (abs(v) * mult).rounded()
        let intPart = Int64(scaled / mult)
        var frac = Int64(scaled) - intPart * Int64(mult)
        var fracStr = ""
        for _ in 0..<places { fracStr = String(frac % 10) + fracStr; frac /= 10 }
        let sign = v < 0 && scaled != 0 ? "-" : ""
        return places > 0 ? "\(sign)\(intPart).\(fracStr)" : "\(sign)\(intPart)"
    }
}
