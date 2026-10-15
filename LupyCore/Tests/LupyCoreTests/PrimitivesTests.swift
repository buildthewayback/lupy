// Tests for JSON, Codable bridge, timestamps, IDs and hashing.

private struct Sample: Codable, Equatable {
    enum Kind: String, Codable { case a, b }
    enum Payload: Codable, Equatable { case none; case text(String); case pair(x: Int, y: Double) }
    var id: LupyID
    var name: String
    var count: Int
    var big: Int64
    var ratio: Double
    var flag: Bool
    var tags: [String]
    var opt: String?
    var kind: Kind
    var nested: [String: Int]
    var payload: Payload
    var when: Timestamp
    var raw: JSONValue
}

func primitivesSuite() -> TestSuite {
    TestSuite(name: "Primitives", cases: [
        TestCase("json round trip with escapes and unicode") { t in
            let text = #"{"a":[1,2.5,-3e2,true,false,null],"s":"line\nbreak \"q\" \\ tab\t é 😀 \u00e9\ud83d\ude00","o":{}}"#
            let v = try JSONParser.parse(text)
            t.equal(v["a"]?[1]?.doubleValue, 2.5)
            t.equal(v["a"]?[2]?.doubleValue, -300)
            t.equal(v["s"]?.stringValue, "line\nbreak \"q\" \\ tab\t é 😀 é😀")
            let again = try JSONParser.parse(JSONWriter.string(v))
            t.equal(again, v)
            let pretty = try JSONParser.parse(JSONWriter.string(v, pretty: true))
            t.equal(pretty, v)
        },
        TestCase("json rejects malformed input") { t in
            for bad in ["", "{", "[1,]", "{\"a\" 1}", "01", "1.", "\"\\x\"", "tru", "[1] x", "\"\u{01}\"", "\"\\ud800\"", "{\"a\":1,}"] {
                t.throwsError("should reject: \(bad)") { _ = try JSONParser.parse(bad) }
            }
        },
        TestCase("json depth limit defends against hostile nesting") { t in
            let deep = String(repeating: "[", count: 400) + String(repeating: "]", count: 400)
            t.throwsError { _ = try JSONParser.parse(deep) }
            let ok = String(repeating: "[", count: 100) + String(repeating: "]", count: 100)
            t.noThrow { _ = try JSONParser.parse(ok) }
        },
        TestCase("json writer is deterministic (sorted keys) and integral numbers have no fraction") { t in
            let v: JSONValue = ["b": 1, "a": 2.5, "c": ["z": true, "y": nil]]
            t.equal(JSONWriter.string(v), #"{"a":2.5,"b":1,"c":{"y":null,"z":true}}"#)
        },
        TestCase("codable bridge round-trips nested models, enums with payloads, optionals, raw json") { t in
            let s = Sample(id: "tsk_1", name: "Ship \"v1\"", count: 3, big: 9_007_199_254_740_993, ratio: 0.25, flag: true,
                           tags: ["x", "y"], opt: nil, kind: .b, nested: ["k": 1], payload: .pair(x: 2, y: 1.5),
                           when: Timestamp(year: 2026, month: 10, day: 15, hour: 12), raw: ["any": [1, "two"]])
            let json = try JSONCoding.encode(s)
            t.equal(json["big"]?.stringValue, "9007199254740993", "large Int64 must not lose precision")
            t.equal(json["when"]?.stringValue, "2026-10-15T12:00:00.000Z")
            let back = try JSONCoding.decode(Sample.self, from: json)
            t.equal(back, s)
            let viaText = try JSONCoding.decode(Sample.self, fromString: try JSONCoding.encodeString(s, pretty: true))
            t.equal(viaText, s)
        },
        TestCase("codable bridge reports missing keys and type mismatches") { t in
            t.throwsError { _ = try JSONCoding.decode(Sample.self, fromString: #"{"id":"x"}"#) }
            struct N: Codable { var n: Int }
            t.throwsError { _ = try JSONCoding.decode(N.self, fromString: #"{"n":"abc"}"#) }
            t.throwsError { _ = try JSONCoding.decode(N.self, fromString: #"{"n":1.5}"#) }
            t.equal(try JSONCoding.decode(N.self, fromString: #"{"n":7}"#).n, 7)
        },
        TestCase("timestamp civil conversion and ISO-8601 parsing") { t in
            let ts = Timestamp(year: 2026, month: 10, day: 15, hour: 17, minute: 29, second: 43, millisecond: 7)
            t.equal(ts.iso8601, "2026-10-15T17:29:43.007Z")
            t.equal(ts.civil.weekday, 4, "2026-10-15 is a Thursday")
            t.equal(Timestamp(millis: 0).iso8601, "1970-01-01T00:00:00.000Z")
            t.equal(Timestamp(year: 2024, month: 2, day: 29).dateOnly, "2024-02-29")
            t.equal(Timestamp(iso8601: "2026-10-15T17:29:43.007Z"), ts)
            t.equal(Timestamp(iso8601: "2026-10-15T23:29:43.007+06:00"), ts)
            t.equal(Timestamp(iso8601: "2026-10-15"), Timestamp(year: 2026, month: 10, day: 15))
            t.equal(Timestamp(iso8601: "2026-10-15T17:29"), Timestamp(year: 2026, month: 10, day: 15, hour: 17, minute: 29))
            t.expect(Timestamp(iso8601: "2026-13-01") == nil)
            t.expect(Timestamp(iso8601: "yesterday") == nil)
            t.equal(Timestamp(millis: -1).iso8601, "1969-12-31T23:59:59.999Z")
            t.equal(ts.monthKey(), "2026-10")
            t.equal(Timestamp(year: 2026, month: 10, day: 31, hour: 23).monthKey(utcOffsetMinutes: 330), "2026-11")
            t.equal(ts.startOfDay(), Timestamp(year: 2026, month: 10, day: 15))
            // Sri Lanka (UTC+5:30): 2026-10-15T20:00Z is already the 16th locally.
            let late = Timestamp(year: 2026, month: 10, day: 15, hour: 20)
            t.equal(late.startOfDay(utcOffsetMinutes: 330), Timestamp(year: 2026, month: 10, day: 15, hour: 18, minute: 30))
        },
        TestCase("sha256 matches FIPS test vectors") { t in
            t.equal(SHA256Digest.hex(""), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
            t.equal(SHA256Digest.hex("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
            t.equal(SHA256Digest.hex("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
                    "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
            t.equal(SHA256Digest.hex(String(repeating: "a", count: 1000)),
                    "41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3")
        },
        TestCase("fnv1a and ids") { t in
            t.equal(FNV1a.hex64(""), "cbf29ce484222325")
            t.equal(FNV1a.hex64("a"), "af63dc4c8601ec8c")
            let g = SequentialIDGenerator()
            t.equal(g.next("tsk").raw, "tsk_0001")
            t.equal(g.next("tsk").raw, "tsk_0002")
            t.equal(g.next("prj").raw, "prj_0001")
            let clock = ManualClock(Timestamp(year: 2026, month: 1, day: 1))
            let r = RandomIDGenerator(clock: clock)
            let a = r.next("tsk"), b = r.next("tsk")
            t.expect(a != b)
            t.expect(a.raw.hasPrefix("tsk_") && a.raw.count == 4 + 22)
            t.equal(a.prefix, "tsk")
        },
        TestCase("text helpers") { t in
            t.equal(TextUtil.trimmed("  hi there \n"), "hi there")
            t.equal(TextUtil.words("Ship v1.2 — NOW!"), ["ship", "v1", "2", "now"])
            t.equal(TextUtil.slug("PENGLAI City: World #1"), "penglai-city-world-1")
            t.equal(TextUtil.truncate("abcdef", 4), "abc…")
            t.equal(TextUtil.fixed(1.256, 2), "1.26")
            t.equal(TextUtil.fixed(-0.5, 1), "-0.5")
            t.equal(TextUtil.formatCents(1234), "$12.34")
            t.equal(TextUtil.formatCents(12.5), "$0.125")
        },
    ])
}
