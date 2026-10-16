// LupyCore — stdlib-only Swift (no Foundation). See docs/DECISIONS.md D-003.
//
// JSON value model, strict RFC 8259 parser and deterministic serializer.
// Used for the event journal, snapshots, exports and cloud-provider payloads.

public enum JSONValue: Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public subscript(key: String) -> JSONValue? {
        if case .object(let o) = self { return o[key] }
        return nil
    }

    public subscript(index: Int) -> JSONValue? {
        if case .array(let a) = self, index >= 0, index < a.count { return a[index] }
        return nil
    }

    public var stringValue: String? { if case .string(let s) = self { return s }; return nil }
    public var doubleValue: Double? { if case .number(let n) = self { return n }; return nil }
    public var intValue: Int? {
        if case .number(let n) = self, n.isFinite, n == n.rounded(), abs(n) < 9.0e15 { return Int(n) }
        return nil
    }
    public var boolValue: Bool? { if case .bool(let b) = self { return b }; return nil }
    public var arrayValue: [JSONValue]? { if case .array(let a) = self { return a }; return nil }
    public var objectValue: [String: JSONValue]? { if case .object(let o) = self { return o }; return nil }
    public var isNull: Bool { if case .null = self { return true }; return false }
}

public struct JSONParseError: Error, Equatable, CustomStringConvertible, Sendable {
    public let message: String
    public let offset: Int
    public var description: String { "JSON parse error at byte \(offset): \(message)" }
}

// MARK: - Parser

public enum JSONParser {
    /// Maximum nesting depth accepted (defends against stack exhaustion from hostile input).
    public static let maxDepth = 256

    public static func parse(_ text: String) throws -> JSONValue {
        try parse(bytes: Array(text.utf8))
    }

    public static func parse(bytes: [UInt8]) throws -> JSONValue {
        var p = Cursor(bytes: bytes)
        p.skipWhitespace()
        let v = try p.parseValue(depth: 0)
        p.skipWhitespace()
        if p.i != bytes.count { throw p.error("trailing characters") }
        return v
    }

    private struct Cursor {
        let bytes: [UInt8]
        var i = 0

        init(bytes: [UInt8]) { self.bytes = bytes }

        func error(_ m: String) -> JSONParseError { JSONParseError(message: m, offset: i) }

        mutating func skipWhitespace() {
            while i < bytes.count {
                let c = bytes[i]
                if c == 0x20 || c == 0x0A || c == 0x0D || c == 0x09 { i += 1 } else { break }
            }
        }

        mutating func parseValue(depth: Int) throws -> JSONValue {
            guard depth < JSONParser.maxDepth else { throw error("nesting too deep") }
            guard i < bytes.count else { throw error("unexpected end of input") }
            switch bytes[i] {
            case UInt8(ascii: "{"): return try parseObject(depth: depth)
            case UInt8(ascii: "["): return try parseArray(depth: depth)
            case UInt8(ascii: "\""): return .string(try parseString())
            case UInt8(ascii: "t"): try expectLiteral("true"); return .bool(true)
            case UInt8(ascii: "f"): try expectLiteral("false"); return .bool(false)
            case UInt8(ascii: "n"): try expectLiteral("null"); return .null
            default: return .number(try parseNumber())
            }
        }

        mutating func expectLiteral(_ lit: String) throws {
            let u = Array(lit.utf8)
            guard i + u.count <= bytes.count, Array(bytes[i..<(i + u.count)]) == u else {
                throw error("invalid literal")
            }
            i += u.count
        }

        mutating func parseObject(depth: Int) throws -> JSONValue {
            i += 1
            var dict: [String: JSONValue] = [:]
            skipWhitespace()
            if i < bytes.count, bytes[i] == UInt8(ascii: "}") { i += 1; return .object(dict) }
            while true {
                skipWhitespace()
                guard i < bytes.count, bytes[i] == UInt8(ascii: "\"") else { throw error("expected object key") }
                let key = try parseString()
                skipWhitespace()
                guard i < bytes.count, bytes[i] == UInt8(ascii: ":") else { throw error("expected ':'") }
                i += 1
                skipWhitespace()
                dict[key] = try parseValue(depth: depth + 1)
                skipWhitespace()
                guard i < bytes.count else { throw error("unterminated object") }
                if bytes[i] == UInt8(ascii: ",") { i += 1; continue }
                if bytes[i] == UInt8(ascii: "}") { i += 1; return .object(dict) }
                throw error("expected ',' or '}'")
            }
        }

        mutating func parseArray(depth: Int) throws -> JSONValue {
            i += 1
            var arr: [JSONValue] = []
            skipWhitespace()
            if i < bytes.count, bytes[i] == UInt8(ascii: "]") { i += 1; return .array(arr) }
            while true {
                skipWhitespace()
                arr.append(try parseValue(depth: depth + 1))
                skipWhitespace()
                guard i < bytes.count else { throw error("unterminated array") }
                if bytes[i] == UInt8(ascii: ",") { i += 1; continue }
                if bytes[i] == UInt8(ascii: "]") { i += 1; return .array(arr) }
                throw error("expected ',' or ']'")
            }
        }

        mutating func parseHex4() throws -> UInt32 {
            guard i + 4 <= bytes.count else { throw error("short unicode escape") }
            var v: UInt32 = 0
            for _ in 0..<4 {
                let c = bytes[i]
                v <<= 4
                switch c {
                case 0x30...0x39: v |= UInt32(c - 0x30)
                case 0x41...0x46: v |= UInt32(c - 0x41 + 10)
                case 0x61...0x66: v |= UInt32(c - 0x61 + 10)
                default: throw error("bad hex digit")
                }
                i += 1
            }
            return v
        }

        mutating func parseString() throws -> String {
            i += 1 // opening quote
            var out: [UInt8] = []
            while true {
                guard i < bytes.count else { throw error("unterminated string") }
                let c = bytes[i]
                if c == UInt8(ascii: "\"") { i += 1; break }
                if c < 0x20 { throw error("control character in string") }
                if c == UInt8(ascii: "\\") {
                    i += 1
                    guard i < bytes.count else { throw error("unterminated escape") }
                    let e = bytes[i]
                    i += 1
                    switch e {
                    case UInt8(ascii: "\""): out.append(0x22)
                    case UInt8(ascii: "\\"): out.append(0x5C)
                    case UInt8(ascii: "/"): out.append(0x2F)
                    case UInt8(ascii: "b"): out.append(0x08)
                    case UInt8(ascii: "f"): out.append(0x0C)
                    case UInt8(ascii: "n"): out.append(0x0A)
                    case UInt8(ascii: "r"): out.append(0x0D)
                    case UInt8(ascii: "t"): out.append(0x09)
                    case UInt8(ascii: "u"):
                        var scalar = try parseHex4()
                        if scalar >= 0xD800 && scalar <= 0xDBFF {
                            // High surrogate: must be followed by \uDC00–\uDFFF.
                            guard i + 1 < bytes.count, bytes[i] == UInt8(ascii: "\\"), bytes[i + 1] == UInt8(ascii: "u") else {
                                throw error("unpaired surrogate")
                            }
                            i += 2
                            let low = try parseHex4()
                            guard low >= 0xDC00 && low <= 0xDFFF else { throw error("invalid low surrogate") }
                            scalar = 0x10000 + ((scalar - 0xD800) << 10) + (low - 0xDC00)
                        } else if scalar >= 0xDC00 && scalar <= 0xDFFF {
                            throw error("unpaired low surrogate")
                        }
                        guard let u = Unicode.Scalar(scalar) else { throw error("invalid scalar") }
                        out.append(contentsOf: Array(String(Character(u)).utf8))
                    default: throw error("invalid escape")
                    }
                } else {
                    out.append(c)
                    i += 1
                }
            }
            // Validate UTF-8 without macOS-15-only APIs: decoding replaces invalid
            // sequences with U+FFFD, so a lossless round trip proves validity.
            let s = String(decoding: out, as: UTF8.self)
            guard s.utf8.elementsEqual(out) else { throw error("invalid UTF-8") }
            return s
        }

        mutating func parseNumber() throws -> Double {
            let start = i
            if i < bytes.count, bytes[i] == UInt8(ascii: "-") { i += 1 }
            guard i < bytes.count else { throw error("bad number") }
            if bytes[i] == UInt8(ascii: "0") {
                i += 1
            } else if bytes[i] >= 0x31 && bytes[i] <= 0x39 {
                while i < bytes.count, bytes[i] >= 0x30 && bytes[i] <= 0x39 { i += 1 }
            } else {
                throw error("unexpected character")
            }
            if i < bytes.count, bytes[i] == UInt8(ascii: ".") {
                i += 1
                let fracStart = i
                while i < bytes.count, bytes[i] >= 0x30 && bytes[i] <= 0x39 { i += 1 }
                if i == fracStart { throw error("bad fraction") }
            }
            if i < bytes.count, bytes[i] == UInt8(ascii: "e") || bytes[i] == UInt8(ascii: "E") {
                i += 1
                if i < bytes.count, bytes[i] == UInt8(ascii: "+") || bytes[i] == UInt8(ascii: "-") { i += 1 }
                let expStart = i
                while i < bytes.count, bytes[i] >= 0x30 && bytes[i] <= 0x39 { i += 1 }
                if i == expStart { throw error("bad exponent") }
            }
            let text = String(decoding: bytes[start..<i], as: UTF8.self)
            guard let d = Double(text) else { throw error("unrepresentable number") }
            return d
        }
    }
}

// MARK: - Serializer

public enum JSONWriter {
    /// Deterministic output: object keys are sorted. `pretty` adds two-space indentation.
    public static func string(_ value: JSONValue, pretty: Bool = false) -> String {
        var out = ""
        out.reserveCapacity(256)
        write(value, into: &out, pretty: pretty, indent: 0)
        return out
    }

    public static func bytes(_ value: JSONValue, pretty: Bool = false) -> [UInt8] {
        Array(string(value, pretty: pretty).utf8)
    }

    static func write(_ v: JSONValue, into out: inout String, pretty: Bool, indent: Int) {
        switch v {
        case .null: out += "null"
        case .bool(let b): out += b ? "true" : "false"
        case .number(let n): out += formatNumber(n)
        case .string(let s): writeString(s, into: &out)
        case .array(let a):
            if a.isEmpty { out += "[]"; return }
            out += "["
            for (idx, el) in a.enumerated() {
                if idx > 0 { out += "," }
                if pretty { out += "\n" + String(repeating: "  ", count: indent + 1) }
                write(el, into: &out, pretty: pretty, indent: indent + 1)
            }
            if pretty { out += "\n" + String(repeating: "  ", count: indent) }
            out += "]"
        case .object(let o):
            if o.isEmpty { out += "{}"; return }
            out += "{"
            for (idx, key) in o.keys.sorted().enumerated() {
                if idx > 0 { out += "," }
                if pretty { out += "\n" + String(repeating: "  ", count: indent + 1) }
                writeString(key, into: &out)
                out += pretty ? ": " : ":"
                write(o[key]!, into: &out, pretty: pretty, indent: indent + 1)
            }
            if pretty { out += "\n" + String(repeating: "  ", count: indent) }
            out += "}"
        }
    }

    static func formatNumber(_ n: Double) -> String {
        guard n.isFinite else { return "null" } // JSON has no NaN/Infinity
        if n == n.rounded(), abs(n) < 9.0e15 {
            return String(Int64(n))
        }
        return "\(n)"
    }

    static func writeString(_ s: String, into out: inout String) {
        out += "\""
        for scalar in s.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            default:
                if scalar.value < 0x20 || scalar.value == 0x2028 || scalar.value == 0x2029 {
                    out += "\\u" + hex4(scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        out += "\""
    }

    static func hex4(_ v: UInt32) -> String {
        let digits = Array("0123456789abcdef")
        var s = ""
        for shift in stride(from: 12, through: 0, by: -4) {
            s.append(digits[Int((v >> UInt32(shift)) & 0xF)])
        }
        return s
    }
}

extension JSONValue: CustomStringConvertible {
    public var description: String { JSONWriter.string(self) }
}

extension JSONValue: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral,
                     ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral, ExpressibleByNilLiteral,
                     ExpressibleByFloatLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
    public init(floatLiteral value: Double) { self = .number(value) }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        var d: [String: JSONValue] = [:]
        for (k, v) in elements { d[k] = v }
        self = .object(d)
    }
    public init(nilLiteral: ()) { self = .null }
}
