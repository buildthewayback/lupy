// Registry of all LupyCore test suites.
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(WASILibc)
import WASILibc
#endif

func allSuites() -> [TestSuite] {
    [
        primitivesSuite(),
        storeSuite(),
    ]
}

func exitProcess(_ code: Int32) -> Never { exit(code) }
