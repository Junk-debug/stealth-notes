import SwiftUI
import AppKit

/// Menu bar (eye icon): float any note, show/hide or close all, open the manager.
struct MenuBarContent: View {
    @EnvironmentObject var store: NotesStore
    @ObservedObject var overlays = OverlayManager.shared
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKeys.hotKey) private var hotKeyIndex = 0

    var body: some View {
        Section("Float a Note") {
            ForEach(store.notes) { note in
                Toggle(note.name, isOn: Binding(
                    get: { overlays.isOpen(note.name) },
                    set: { _ in overlays.toggleOverlay(for: note.name) }
                ))
            }
        }
        Divider()
        Button("Show/Hide All Overlays") {
            OverlayManager.shared.toggleAllVisibility()
        }
        .keyboardShortcut(.none)
        .badge(Text(hotKeyOptions[hotKeyIndex].title))
        Button("Close All Overlays") {
            OverlayManager.shared.closeAll()
        }
        .disabled(overlays.openNotes.isEmpty)
        Divider()
        Button("Open Stealth Notes…") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "manager")
        }
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit Stealth Notes") { NSApp.terminate(nil) }
    }
}
