// Minimal test harness (XCTest/swift-testing are unavailable in the WebAssembly toolchain; see D-012).
// The same binary runs in the Arena sandbox (WASI) and natively on macOS.

final class TestContext {
    let name: String
    private(set) var failures: [String] = []
    private(set) var checks = 0

    init(name: String) { self.name = name }

    func expect(_ condition: Bool, _ message: @autoclosure () -> String = "", file: String = #fileID, line: Int = #line) {
        checks += 1
        if !condition { failures.append("\(file):\(line): expectation failed. \(message())") }
    }

    func equal<T: Equatable>(_ a: T, _ b: T, _ message: @autoclosure () -> String = "", file: String = #fileID, line: Int = #line) {
        checks += 1
        if a != b { failures.append("\(file):\(line): \(a) != \(b). \(message())") }
    }

    func notNil<T>(_ v: T?, _ message: @autoclosure () -> String = "", file: String = #fileID, line: Int = #line) {
        checks += 1
        if v == nil { failures.append("\(file):\(line): unexpected nil. \(message())") }
    }

    func throwsError(_ message: @autoclosure () -> String = "", file: String = #fileID, line: Int = #line, _ block: () throws -> Void) {
        checks += 1
        do { try block(); failures.append("\(file):\(line): expected an error. \(message())") } catch {}
    }

    func noThrow(_ message: @autoclosure () -> String = "", file: String = #fileID, line: Int = #line, _ block: () throws -> Void) {
        checks += 1
        do { try block() } catch { failures.append("\(file):\(line): unexpected error \(error). \(message())") }
    }

    func fail(_ message: String, file: String = #fileID, line: Int = #line) {
        checks += 1
        failures.append("\(file):\(line): \(message)")
    }
}

struct TestCase {
    let name: String
    let body: (TestContext) throws -> Void
    init(_ name: String, _ body: @escaping (TestContext) throws -> Void) { self.name = name; self.body = body }
}

struct TestSuite {
    let name: String
    let cases: [TestCase]
}

func runSuites(_ suites: [TestSuite], filter: String?) -> Int32 {
    var total = 0, failed = 0, checks = 0
    var failedNames: [String] = []
    for suite in suites {
        for tc in suite.cases {
            let full = "\(suite.name).\(tc.name)"
            if let f = filter, !full.lowercased().contains(f.lowercased()) { continue }
            total += 1
            let ctx = TestContext(name: full)
            do { try tc.body(ctx) } catch { ctx.fail("threw \(error)") }
            checks += ctx.checks
            if ctx.failures.isEmpty {
                print("  ✓ \(full)")
            } else {
                failed += 1
                failedNames.append(full)
                print("  ✗ \(full)")
                for f in ctx.failures { print("      \(f)") }
            }
        }
    }
    print("")
    print("RESULT: \(total - failed)/\(total) tests passed, \(checks) checks, \(failed) failed")
    if !failedNames.isEmpty { print("FAILED: " + failedNames.joined(separator: ", ")) }
    return failed == 0 ? 0 : 1
}
