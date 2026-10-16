// LupyCore — Codable <-> JSONValue bridge (Foundation-free JSONEncoder/JSONDecoder equivalent).

public struct JSONCoding {
    /// Encode any Encodable value to a JSONValue tree.
    public static func encode<T: Encodable>(_ value: T) throws -> JSONValue {
        let ref = EncRef()
        try encodeValue(value, into: ref, path: [])
        return ref.resolve()
    }

    public static func decode<T: Decodable>(_ type: T.Type, from value: JSONValue) throws -> T {
        try decodeValue(type, from: value, path: [])
    }

    public static func encodeString<T: Encodable>(_ value: T, pretty: Bool = false) throws -> String {
        JSONWriter.string(try encode(value), pretty: pretty)
    }

    public static func decode<T: Decodable>(_ type: T.Type, fromString s: String) throws -> T {
        try decode(type, from: try JSONParser.parse(s))
    }

    // MARK: internals

    static func encodeValue<T: Encodable>(_ value: T, into ref: EncRef, path: [CodingKey]) throws {
        if let j = value as? JSONValue { ref.value = j; return }
        try value.encode(to: Enc(ref: ref, codingPath: path))
    }

    static func decodeValue<T: Decodable>(_ type: T.Type, from value: JSONValue, path: [CodingKey]) throws -> T {
        if T.self == JSONValue.self, let v = value as? T { return v }
        return try T(from: Dec(value: value, codingPath: path))
    }
}

// MARK: - Encoding

final class EncRef {
    var value: JSONValue?
    var object: [String: EncRef]?
    var array: [EncRef]?

    func resolve() -> JSONValue {
        if let v = value { return v }
        if let o = object {
            var d: [String: JSONValue] = [:]
            for (k, r) in o { d[k] = r.resolve() }
            return .object(d)
        }
        if let a = array { return .array(a.map { $0.resolve() }) }
        return .object([:])
    }
}

struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
    init(intValue: Int) { self.stringValue = String(intValue); self.intValue = intValue }
    static let superKey = AnyKey(stringValue: "super")
}

private func encodeInt64(_ v: Int64) -> JSONValue {
    // Doubles are exact up to 2^53; larger magnitudes are written as strings to avoid loss.
    if v > 9_007_199_254_740_992 || v < -9_007_199_254_740_992 { return .string(String(v)) }
    return .number(Double(v))
}

private func encodeUInt64(_ v: UInt64) -> JSONValue {
    if v > 9_007_199_254_740_992 { return .string(String(v)) }
    return .number(Double(v))
}

struct Enc: Encoder {
    let ref: EncRef
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { [:] }

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        if ref.object == nil { ref.object = [:] }
        return KeyedEncodingContainer(KeyedEnc<Key>(ref: ref, codingPath: codingPath))
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        if ref.array == nil { ref.array = [] }
        return UnkeyedEnc(ref: ref, codingPath: codingPath)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        SingleEnc(ref: ref, codingPath: codingPath)
    }
}

struct KeyedEnc<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let ref: EncRef
    var codingPath: [CodingKey]

    private func set(_ v: JSONValue, _ key: Key) {
        let r = EncRef(); r.value = v
        ref.object![key.stringValue] = r
    }

    mutating func encodeNil(forKey key: Key) throws { set(.null, key) }
    mutating func encode(_ value: Bool, forKey key: Key) throws { set(.bool(value), key) }
    mutating func encode(_ value: String, forKey key: Key) throws { set(.string(value), key) }
    mutating func encode(_ value: Double, forKey key: Key) throws { set(.number(value), key) }
    mutating func encode(_ value: Float, forKey key: Key) throws { set(.number(Double(value)), key) }
    mutating func encode(_ value: Int, forKey key: Key) throws { set(encodeInt64(Int64(value)), key) }
    mutating func encode(_ value: Int8, forKey key: Key) throws { set(.number(Double(value)), key) }
    mutating func encode(_ value: Int16, forKey key: Key) throws { set(.number(Double(value)), key) }
    mutating func encode(_ value: Int32, forKey key: Key) throws { set(.number(Double(value)), key) }
    mutating func encode(_ value: Int64, forKey key: Key) throws { set(encodeInt64(value), key) }
    mutating func encode(_ value: UInt, forKey key: Key) throws { set(encodeUInt64(UInt64(value)), key) }
    mutating func encode(_ value: UInt8, forKey key: Key) throws { set(.number(Double(value)), key) }
    mutating func encode(_ value: UInt16, forKey key: Key) throws { set(.number(Double(value)), key) }
    mutating func encode(_ value: UInt32, forKey key: Key) throws { set(.number(Double(value)), key) }
    mutating func encode(_ value: UInt64, forKey key: Key) throws { set(encodeUInt64(value), key) }

    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        let child = EncRef()
        ref.object![key.stringValue] = child
        try JSONCoding.encodeValue(value, into: child, path: codingPath + [key])
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        let child = EncRef(); child.object = [:]
        ref.object![key.stringValue] = child
        return KeyedEncodingContainer(KeyedEnc<NestedKey>(ref: child, codingPath: codingPath + [key]))
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let child = EncRef(); child.array = []
        ref.object![key.stringValue] = child
        return UnkeyedEnc(ref: child, codingPath: codingPath + [key])
    }

    mutating func superEncoder() -> Encoder {
        let child = EncRef()
        ref.object![AnyKey.superKey.stringValue] = child
        return Enc(ref: child, codingPath: codingPath + [AnyKey.superKey])
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
        let child = EncRef()
        ref.object![key.stringValue] = child
        return Enc(ref: child, codingPath: codingPath + [key])
    }
}

struct UnkeyedEnc: UnkeyedEncodingContainer {
    let ref: EncRef
    var codingPath: [CodingKey]
    var count: Int { ref.array!.count }

    private func push(_ v: JSONValue) { let r = EncRef(); r.value = v; ref.array!.append(r) }
    private var nextKey: AnyKey { AnyKey(intValue: count) }

    mutating func encodeNil() throws { push(.null) }
    mutating func encode(_ value: Bool) throws { push(.bool(value)) }
    mutating func encode(_ value: String) throws { push(.string(value)) }
    mutating func encode(_ value: Double) throws { push(.number(value)) }
    mutating func encode(_ value: Float) throws { push(.number(Double(value))) }
    mutating func encode(_ value: Int) throws { push(encodeInt64(Int64(value))) }
    mutating func encode(_ value: Int8) throws { push(.number(Double(value))) }
    mutating func encode(_ value: Int16) throws { push(.number(Double(value))) }
    mutating func encode(_ value: Int32) throws { push(.number(Double(value))) }
    mutating func encode(_ value: Int64) throws { push(encodeInt64(value)) }
    mutating func encode(_ value: UInt) throws { push(encodeUInt64(UInt64(value))) }
    mutating func encode(_ value: UInt8) throws { push(.number(Double(value))) }
    mutating func encode(_ value: UInt16) throws { push(.number(Double(value))) }
    mutating func encode(_ value: UInt32) throws { push(.number(Double(value))) }
    mutating func encode(_ value: UInt64) throws { push(encodeUInt64(value)) }

    mutating func encode<T: Encodable>(_ value: T) throws {
        let key = nextKey
        let child = EncRef()
        ref.array!.append(child)
        try JSONCoding.encodeValue(value, into: child, path: codingPath + [key])
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        let key = nextKey
        let child = EncRef(); child.object = [:]
        ref.array!.append(child)
        return KeyedEncodingContainer(KeyedEnc<NestedKey>(ref: child, codingPath: codingPath + [key]))
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let key = nextKey
        let child = EncRef(); child.array = []
        ref.array!.append(child)
        return UnkeyedEnc(ref: child, codingPath: codingPath + [key])
    }

    mutating func superEncoder() -> Encoder {
        let key = nextKey
        let child = EncRef()
        ref.array!.append(child)
        return Enc(ref: child, codingPath: codingPath + [key])
    }
}

struct SingleEnc: SingleValueEncodingContainer {
    let ref: EncRef
    var codingPath: [CodingKey]

    mutating func encodeNil() throws { ref.value = .null }
    mutating func encode(_ value: Bool) throws { ref.value = .bool(value) }
    mutating func encode(_ value: String) throws { ref.value = .string(value) }
    mutating func encode(_ value: Double) throws { ref.value = .number(value) }
    mutating func encode(_ value: Float) throws { ref.value = .number(Double(value)) }
    mutating func encode(_ value: Int) throws { ref.value = encodeInt64(Int64(value)) }
    mutating func encode(_ value: Int8) throws { ref.value = .number(Double(value)) }
    mutating func encode(_ value: Int16) throws { ref.value = .number(Double(value)) }
    mutating func encode(_ value: Int32) throws { ref.value = .number(Double(value)) }
    mutating func encode(_ value: Int64) throws { ref.value = encodeInt64(value) }
    mutating func encode(_ value: UInt) throws { ref.value = encodeUInt64(UInt64(value)) }
    mutating func encode(_ value: UInt8) throws { ref.value = .number(Double(value)) }
    mutating func encode(_ value: UInt16) throws { ref.value = .number(Double(value)) }
    mutating func encode(_ value: UInt32) throws { ref.value = .number(Double(value)) }
    mutating func encode(_ value: UInt64) throws { ref.value = encodeUInt64(value) }
    mutating func encode<T: Encodable>(_ value: T) throws {
        try JSONCoding.encodeValue(value, into: ref, path: codingPath)
    }
}

// MARK: - Decoding

private func typeName(_ v: JSONValue) -> String {
    switch v {
    case .null: return "null"
    case .bool: return "bool"
    case .number: return "number"
    case .string: return "string"
    case .array: return "array"
    case .object: return "object"
    }
}

private func mismatch(_ type: Any.Type, _ v: JSONValue, _ path: [CodingKey]) -> DecodingError {
    .typeMismatch(type, .init(codingPath: path, debugDescription: "expected \(type), found \(typeName(v))"))
}

private func toDouble(_ v: JSONValue, _ path: [CodingKey]) throws -> Double {
    if case .number(let n) = v { return n }
    throw mismatch(Double.self, v, path)
}

private func toInteger<I: FixedWidthInteger>(_ type: I.Type, _ v: JSONValue, _ path: [CodingKey]) throws -> I {
    switch v {
    case .number(let n):
        guard n.isFinite, n == n.rounded(), let i = I(exactly: n) else {
            throw DecodingError.dataCorrupted(.init(codingPath: path, debugDescription: "\(n) is not a valid \(I.self)"))
        }
        return i
    case .string(let s):
        // Large 64-bit values are serialized as strings (see encodeInt64).
        guard let i = I(s) else { throw mismatch(I.self, v, path) }
        return i
    default:
        throw mismatch(I.self, v, path)
    }
}

struct Dec: Decoder {
    let value: JSONValue
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { [:] }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard case .object(let o) = value else { throw mismatch([String: JSONValue].self, value, codingPath) }
        return KeyedDecodingContainer(KeyedDec<Key>(object: o, codingPath: codingPath))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard case .array(let a) = value else { throw mismatch([JSONValue].self, value, codingPath) }
        return UnkeyedDec(array: a, codingPath: codingPath)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        SingleDec(value: value, codingPath: codingPath)
    }
}

struct KeyedDec<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let object: [String: JSONValue]
    var codingPath: [CodingKey]

    var allKeys: [Key] { object.keys.compactMap { Key(stringValue: $0) } }
    func contains(_ key: Key) -> Bool { object[key.stringValue] != nil }

    private func get(_ key: Key) throws -> JSONValue {
        guard let v = object[key.stringValue] else {
            throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: "missing key '\(key.stringValue)'"))
        }
        return v
    }

    func decodeNil(forKey key: Key) throws -> Bool { (try get(key)).isNull }
    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        let v = try get(key)
        guard case .bool(let b) = v else { throw mismatch(type, v, codingPath + [key]) }
        return b
    }
    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        let v = try get(key)
        guard case .string(let s) = v else { throw mismatch(type, v, codingPath + [key]) }
        return s
    }
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double { try toDouble(try get(key), codingPath + [key]) }
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float { Float(try toDouble(try get(key), codingPath + [key])) }
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int { try toInteger(type, try get(key), codingPath + [key]) }
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { try toInteger(type, try get(key), codingPath + [key]) }
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { try toInteger(type, try get(key), codingPath + [key]) }
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { try toInteger(type, try get(key), codingPath + [key]) }
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { try toInteger(type, try get(key), codingPath + [key]) }
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { try toInteger(type, try get(key), codingPath + [key]) }
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { try toInteger(type, try get(key), codingPath + [key]) }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { try toInteger(type, try get(key), codingPath + [key]) }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { try toInteger(type, try get(key), codingPath + [key]) }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { try toInteger(type, try get(key), codingPath + [key]) }

    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        try JSONCoding.decodeValue(type, from: try get(key), path: codingPath + [key])
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        let v = try get(key)
        guard case .object(let o) = v else { throw mismatch([String: JSONValue].self, v, codingPath + [key]) }
        return KeyedDecodingContainer(KeyedDec<NestedKey>(object: o, codingPath: codingPath + [key]))
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        let v = try get(key)
        guard case .array(let a) = v else { throw mismatch([JSONValue].self, v, codingPath + [key]) }
        return UnkeyedDec(array: a, codingPath: codingPath + [key])
    }

    func superDecoder() throws -> Decoder {
        Dec(value: object[AnyKey.superKey.stringValue] ?? .null, codingPath: codingPath + [AnyKey.superKey])
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        Dec(value: object[key.stringValue] ?? .null, codingPath: codingPath + [key])
    }
}

struct UnkeyedDec: UnkeyedDecodingContainer {
    let array: [JSONValue]
    var codingPath: [CodingKey]
    var currentIndex = 0

    init(array: [JSONValue], codingPath: [CodingKey]) {
        self.array = array
        self.codingPath = codingPath
    }

    var count: Int? { array.count }
    var isAtEnd: Bool { currentIndex >= array.count }

    private mutating func next(_ type: Any.Type) throws -> (JSONValue, [CodingKey]) {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(type, .init(codingPath: codingPath, debugDescription: "unkeyed container is at end"))
        }
        let path = codingPath + [AnyKey(intValue: currentIndex)]
        let v = array[currentIndex]
        currentIndex += 1
        return (v, path)
    }

    mutating func decodeNil() throws -> Bool {
        guard !isAtEnd else { return false }
        if array[currentIndex].isNull { currentIndex += 1; return true }
        return false
    }
    mutating func decode(_ type: Bool.Type) throws -> Bool {
        let (v, p) = try next(type)
        guard case .bool(let b) = v else { throw mismatch(type, v, p) }
        return b
    }
    mutating func decode(_ type: String.Type) throws -> String {
        let (v, p) = try next(type)
        guard case .string(let s) = v else { throw mismatch(type, v, p) }
        return s
    }
    mutating func decode(_ type: Double.Type) throws -> Double { let (v, p) = try next(type); return try toDouble(v, p) }
    mutating func decode(_ type: Float.Type) throws -> Float { let (v, p) = try next(type); return Float(try toDouble(v, p)) }
    mutating func decode(_ type: Int.Type) throws -> Int { let (v, p) = try next(type); return try toInteger(type, v, p) }
    mutating func decode(_ type: Int8.Type) throws -> Int8 { let (v, p) = try next(type); return try toInteger(type, v, p) }
    mutating func decode(_ type: Int16.Type) throws -> Int16 { let (v, p) = try next(type); return try toInteger(type, v, p) }
    mutating func decode(_ type: Int32.Type) throws -> Int32 { let (v, p) = try next(type); return try toInteger(type, v, p) }
    mutating func decode(_ type: Int64.Type) throws -> Int64 { let (v, p) = try next(type); return try toInteger(type, v, p) }
    mutating func decode(_ type: UInt.Type) throws -> UInt { let (v, p) = try next(type); return try toInteger(type, v, p) }
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 { let (v, p) = try next(type); return try toInteger(type, v, p) }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 { let (v, p) = try next(type); return try toInteger(type, v, p) }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 { let (v, p) = try next(type); return try toInteger(type, v, p) }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 { let (v, p) = try next(type); return try toInteger(type, v, p) }

    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let (v, p) = try next(type)
        return try JSONCoding.decodeValue(type, from: v, path: p)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        let (v, p) = try next([String: JSONValue].self)
        guard case .object(let o) = v else { throw mismatch([String: JSONValue].self, v, p) }
        return KeyedDecodingContainer(KeyedDec<NestedKey>(object: o, codingPath: p))
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        let (v, p) = try next([JSONValue].self)
        guard case .array(let a) = v else { throw mismatch([JSONValue].self, v, p) }
        return UnkeyedDec(array: a, codingPath: p)
    }

    mutating func superDecoder() throws -> Decoder {
        let (v, p) = try next(JSONValue.self)
        return Dec(value: v, codingPath: p)
    }
}

struct SingleDec: SingleValueDecodingContainer {
    let value: JSONValue
    var codingPath: [CodingKey]

    func decodeNil() -> Bool { value.isNull }
    func decode(_ type: Bool.Type) throws -> Bool {
        guard case .bool(let b) = value else { throw mismatch(type, value, codingPath) }
        return b
    }
    func decode(_ type: String.Type) throws -> String {
        guard case .string(let s) = value else { throw mismatch(type, value, codingPath) }
        return s
    }
    func decode(_ type: Double.Type) throws -> Double { try toDouble(value, codingPath) }
    func decode(_ type: Float.Type) throws -> Float { Float(try toDouble(value, codingPath)) }
    func decode(_ type: Int.Type) throws -> Int { try toInteger(type, value, codingPath) }
    func decode(_ type: Int8.Type) throws -> Int8 { try toInteger(type, value, codingPath) }
    func decode(_ type: Int16.Type) throws -> Int16 { try toInteger(type, value, codingPath) }
    func decode(_ type: Int32.Type) throws -> Int32 { try toInteger(type, value, codingPath) }
    func decode(_ type: Int64.Type) throws -> Int64 { try toInteger(type, value, codingPath) }
    func decode(_ type: UInt.Type) throws -> UInt { try toInteger(type, value, codingPath) }
    func decode(_ type: UInt8.Type) throws -> UInt8 { try toInteger(type, value, codingPath) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try toInteger(type, value, codingPath) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try toInteger(type, value, codingPath) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try toInteger(type, value, codingPath) }
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try JSONCoding.decodeValue(type, from: value, path: codingPath)
    }
}

// MARK: - JSONValue: Codable (works with any coder, incl. Foundation's on macOS)

extension JSONValue: Codable {
    public init(from decoder: Decoder) throws {
        if let d = decoder as? Dec { self = d.value; return }
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else if let o = try? c.decode([String: JSONValue].self) { self = .object(o) }
        else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "unsupported JSON value") }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n): try c.encode(n)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }
}
