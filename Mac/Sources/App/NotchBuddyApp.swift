import SwiftUI
import AppKit

// Lupy: the entry point is LupyMain (Sources/Lupy/LupyMain.swift), which runs the headless
// self-test when asked and otherwise starts this app unchanged.
struct NotchBuddyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
        #if !APPSTORE
        .commands {
            // ⌘, and Coucou → Settings… open the notch's pages of the Coucou window.
            CommandGroup(replacing: .appSettings) {
                Button(NSLocalizedString("Settings…", comment: "")) {
                    delegate.openSettings()
                }
                .keyboardShortcut(",")
            }
        }
        #endif
    }
}
