// Lupy — entry point. `Lupy --self-test [--report path]` runs the native self-test of the
// assistant core and exits (CI, support). `Lupy --control-self-test [--report path]` exercises
// computer control and the Lupy cursor on TextEdit. Otherwise Coucou's app starts as it always
// has, with Lupy's assistant started from its app delegate.

import AppKit
import SwiftUI

@main
enum LupyMain {
    @MainActor
    static func main() {
        let args = CommandLine.arguments
        if args.contains("--self-test") {
            exit(LupySelfTest.run(arguments: args))
        }
        if args.contains("--control-self-test") {
            LupyControlSelfTest.runAndExit(arguments: args)
        }
        NotchBuddyApp.main()
    }
}
