import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        HotKeyCenter.shared.register(optionIndex: UserDefaults.standard.integer(forKey: SettingsKeys.hotKey))
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct StealthNotesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("Stealth Notes", id: "manager") {
            ManagerView()
                .environmentObject(NotesStore.shared)
                .frame(minWidth: 560, minHeight: 380)
        }
        .defaultSize(width: 720, height: 480)

        Settings {
            SettingsView()
        }

        MenuBarExtra("Stealth Notes", systemImage: "eye") {
            MenuBarContent()
                .environmentObject(NotesStore.shared)
        }
    }
}
