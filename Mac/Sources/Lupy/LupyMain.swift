// Lupy — entry point. `Lupy --self-test [--report path]` runs the native self-test of the
// assistant core and exits (CI, support). `Lupy --character-self-test` rasterises the
// character renderer at 24/32/64/256 pt and checks it actually draws. `Lupy --control-self-test [--report path]` exercises
// computer control and the Lupy cursor on TextEdit. `Lupy --chat-self-test [--report path]`
// drives the island's conversation loop end-to-end. Otherwise Coucou's app starts as it always
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
        if args.contains("--chat-self-test") {
            exit(LupyChatSelfTest.run(arguments: args))
        }
        if args.contains("--character-self-test") {
            exit(LupyCharacterSelfTest.run(arguments: args))
        }
        if args.contains("--snapshot-states") {
            exit(LupySnapshotHarness.run(arguments: args))
        }
        if args.contains("--character-preview") {
            // Look at the character rig on its own, with a real mouse (LupyCanvasView).
            LupyCharacterPreview.run()
            return
        }
        NotchBuddyApp.main()
    }
}
