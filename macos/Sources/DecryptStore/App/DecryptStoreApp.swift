import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) { NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
@main struct DecryptStoreApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var store = Store()
    var body: some Scene {
        WindowGroup("Decrypt App Store") { ContentView(store: store).frame(minWidth: 960, minHeight: 640) }
            .defaultSize(width: 1180, height: 780)
            .commands {
                CommandGroup(after: .newItem) { Button("Open IPA…") { store.importIPA() }.keyboardShortcut("o") }
            }
        SwiftUI.Settings { SettingsView(store: store) }
    }
}
