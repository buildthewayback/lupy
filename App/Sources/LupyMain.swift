// Lupy macOS shell — entry point, scenes and app delegate.

import AppKit
import SwiftUI

@main
enum LupyMain {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--self-test") {
            exit(SelfTest.run(arguments: CommandLine.arguments))
        }
        LupyApp.main()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = AppModel.shared
        IslandController.shared = IslandController(model: model)
        IslandController.shared?.setVisible(model.showIsland)
        model.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

struct LupyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var model = AppModel.shared

    var body: some Scene {
        WindowGroup("Lupy", id: "main") {
            MainWindow()
                .environment(model)
                .frame(minWidth: 940, minHeight: 620)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button(model.state.settings.globalPause ? "Resume Lupy" : "Pause Lupy") {
                    model.act { try $0.setGlobalPause(!$0.state.settings.globalPause, reason: "Paused from the menu"); return [] }
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra {
            MenuBarContent()
                .environment(model)
                .preferredColorScheme(.dark)
        } label: {
            Image(systemName: model.attention.items.isEmpty ? "moon.stars" : "moon.stars.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarContent: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                LupyCharacterView(mood: model.mood, size: 36, fps: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lupy").font(.system(size: 13, weight: .semibold))
                    Text(model.islandHeadline).font(.system(size: 11)).foregroundColor(LupyTheme.secondary)
                }
            }
            Divider()
            ForEach(model.attention.items.prefix(4)) { item in
                Button {
                    model.focus(item)
                    openWindow(id: "main")
                    NSApp.activate()
                } label: {
                    Label(item.title, systemImage: "circle.fill").labelStyle(.titleOnly).lineLimit(1)
                }
                .buttonStyle(.plain)
            }
            Button("Open Lupy") { openWindow(id: "main"); NSApp.activate() }
            Toggle("Show notch island", isOn: Binding(get: { model.showIsland }, set: { model.setShowIsland($0) }))
            Button(model.state.settings.globalPause ? "Resume Lupy" : "Pause everything") {
                model.act { try $0.setGlobalPause(!$0.state.settings.globalPause, reason: "Paused from the menu bar"); return [] }
            }
            Divider()
            Button("Quit Lupy") { NSApp.terminate(nil) }
        }
        .padding(14)
        .frame(width: 280)
        .onAppear { model.openWindowAction = openWindow }
    }
}
