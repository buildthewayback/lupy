// LupyCore test runner entry point.
// Usage: lupy-core-tests [filter]

let filter = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : nil
let suites: [TestSuite] = allSuites()
print("LupyCore tests — \(suites.reduce(0) { $0 + $1.cases.count }) cases")
let code = runSuites(suites, filter: filter)
exitProcess(code)
