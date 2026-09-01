import SwiftUI
import AppKit
import Carbon.HIToolbox

// MARK: - Model

struct Note: Identifiable, Equatable {
    var name: String
    var text: String
    var id: String { name }
}

final class NotesStore: ObservableObject {
    static let shared = NotesStore()

    @Published var notes: [Note] = []
    let directory: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = appSupport.appendingPathComponent("StealthNotes/Notes", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        load()
        if notes.isEmpty {
            _ = create(named: "Welcome", text: "Your presentation notes live here.\n\nClick the eye button in the toolbar to float this note above every window — including full-screen slides. Floating notes are invisible to screen sharing, recording and screenshots.")
        }
    }

    func load() {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        notes = files
            .filter { $0.pathExtension == "txt" }
            .map { Note(name: $0.deletingPathExtension().lastPathComponent, text: (try? String(contentsOf: $0, encoding: .utf8)) ?? "") }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func url(for name: String) -> URL {
        directory.appendingPathComponent(name).appendingPathExtension("txt")
    }

    func note(named name: String) -> Note? {
        notes.first { $0.name == name }
    }

    func update(name: String, text: String) {
        guard let idx = notes.firstIndex(where: { $0.name == name }) else { return }
        notes[idx].text = text
        try? text.write(to: url(for: name), atomically: true, encoding: .utf8)
    }

    func create(named requested: String, text: String = "") -> String {
        let base = sanitize(requested).isEmpty ? "New Note" : sanitize(requested)
        var name = base
        var counter = 2
        while notes.contains(where: { $0.name == name }) {
            name = "\(base) \(counter)"
            counter += 1
        }
        try? text.write(to: url(for: name), atomically: true, encoding: .utf8)
        notes.append(Note(name: name, text: text))
        notes.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return name
    }

    func rename(_ name: String, to requested: String) -> String? {
        let newName = sanitize(requested)
        guard !newName.isEmpty, newName != name, !notes.contains(where: { $0.name == newName }) else { return nil }
        do {
            try FileManager.default.moveItem(at: url(for: name), to: url(for: newName))
        } catch { return nil }
        if let idx = notes.firstIndex(where: { $0.name == name }) {
            notes[idx].name = newName
        }
        notes.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return newName
    }

    func delete(_ name: String) {
        try? FileManager.default.trashItem(at: url(for: name), resultingItemURL: nil)
        notes.removeAll { $0.name == name }
    }

    private func sanitize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }
}

// MARK: - Appearance settings

enum ThemePreset: String, CaseIterable, Identifiable {
    case dark, light, midnight, sepia, matrix
    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .midnight: return "Midnight"
        case .sepia: return "Sepia"
        case .matrix: return "Matrix"
        }
    }
    var background: Color {
        switch self {
        case .dark: return Color(nsColor: .windowBackgroundColor)
        case .light: return .white
        case .midnight: return Color(red: 0.06, green: 0.10, blue: 0.18)
        case .sepia: return Color(red: 0.96, green: 0.93, blue: 0.85)
        case .matrix: return Color(red: 0.02, green: 0.05, blue: 0.02)
        }
    }
    var text: Color {
        switch self {
        case .dark: return .white
        case .light: return .black
        case .midnight: return Color(red: 0.86, green: 0.90, blue: 0.96)
        case .sepia: return Color(red: 0.36, green: 0.27, blue: 0.21)
        case .matrix: return Color(red: 0.3, green: 0.95, blue: 0.4)
        }
    }
    var isLight: Bool { self == .light || self == .sepia }
}

enum FontPreset: String, CaseIterable, Identifiable {
    case system, rounded, serif, mono
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "System"
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        case .mono: return "Monospaced"
        }
    }
    var design: Font.Design {
        switch self {
        case .system: return .default
        case .rounded: return .rounded
        case .serif: return .serif
        case .mono: return .monospaced
        }
    }
}

enum SettingsKeys {
    static let theme = "themePreset"
    static let font = "fontPreset"
    static let fontSize = "overlayFontSize"
    static let opacity = "overlayOpacity"
    static let hotKey = "hotKeyIndex"
}

// MARK: - Overlay windows

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
}

final class OverlayManager: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = OverlayManager()

    @Published var openNotes: Set<String> = []
    private var panels: [String: OverlayPanel] = [:]
    private var cascadeOffset: CGFloat = 0

    func isOpen(_ name: String) -> Bool { openNotes.contains(name) }

    func toggleOverlay(for name: String) {
        if isOpen(name) { close(name) } else { open(name) }
    }

    func open(_ name: String) {
        guard panels[name] == nil else {
            panels[name]?.orderFrontRegardless()
            return
        }
        let panel = OverlayPanel(
            contentRect: NSRect(x: 120 + cascadeOffset, y: 300 - cascadeOffset, width: 320, height: 340),
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        cascadeOffset = (cascadeOffset + 28).truncatingRemainder(dividingBy: 140)
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        // The whole point: exclude overlays from screen capture / sharing / recording.
        panel.sharingType = .none

        let host = NSHostingView(rootView: OverlayView(noteName: name).environmentObject(NotesStore.shared))
        panel.contentView = host
        panel.setFrameAutosaveName("overlay-\(name)")
        panel.orderFrontRegardless()

        panels[name] = panel
        openNotes.insert(name)
    }

    func close(_ name: String) {
        panels[name]?.close()
    }

    func closeAll() {
        for name in Array(openNotes) { close(name) }
    }

    func windowWillClose(_ notification: Notification) {
        guard let panel = notification.object as? OverlayPanel,
              let name = panels.first(where: { $0.value === panel })?.key else { return }
        panels.removeValue(forKey: name)
        openNotes.remove(name)
    }

    func toggleAllVisibility() {
        guard !panels.isEmpty else { return }
        let anyVisible = panels.values.contains { $0.isVisible }
        for panel in panels.values {
            if anyVisible { panel.orderOut(nil) } else { panel.orderFrontRegardless() }
        }
    }
}

// MARK: - Overlay view

struct OverlayView: View {
    let noteName: String
    @EnvironmentObject var store: NotesStore
    @AppStorage(SettingsKeys.theme) private var themeRaw = ThemePreset.dark.rawValue
    @AppStorage(SettingsKeys.font) private var fontRaw = FontPreset.system.rawValue
    @AppStorage(SettingsKeys.fontSize) private var fontSize = 16.0
    @AppStorage(SettingsKeys.opacity) private var opacity = 0.85
    @State private var hovering = false

    private var theme: ThemePreset { ThemePreset(rawValue: themeRaw) ?? .dark }
    private var fontPreset: FontPreset { FontPreset(rawValue: fontRaw) ?? .system }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                Text(store.note(named: noteName)?.text ?? "")
                    .font(.system(size: fontSize, design: fontPreset.design))
                    .foregroundStyle(theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.top, 30)
                    .padding(.bottom, 12)
            }

            // Header: note name + close button, fades in on hover.
            HStack(spacing: 6) {
                Text(noteName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.text.opacity(0.45))
                    .lineLimit(1)
                Spacer()
                if hovering {
                    Button {
                        OverlayManager.shared.close(noteName)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(theme.text.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .help("Close overlay")
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
        .frame(minWidth: 200, minHeight: 120)
        .background(theme.background.opacity(opacity))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(theme.text.opacity(0.08), lineWidth: 1)
        )
        .onHover { hovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: hovering)
        .environment(\.colorScheme, theme.isLight ? .light : .dark)
    }
}

// MARK: - Manager window

struct ManagerView: View {
    @EnvironmentObject var store: NotesStore
    @ObservedObject var overlays = OverlayManager.shared
    @State private var selection: String?
    @State private var editingNote: String?
    @State private var pendingName = ""
    @FocusState private var renameFieldFocused: Bool

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(store.notes) { note in
                    row(for: note)
                        .tag(note.name)
                }
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 200)
            .toolbar {
                ToolbarItem {
                    Button(action: createNote) {
                        Label("New Note", systemImage: "square.and.pencil")
                    }
                    .help("New note")
                }
            }
            .onChange(of: renameFieldFocused) { _, focused in
                if !focused, editingNote != nil { commitRename() }
            }
        } detail: {
            if let name = selection, store.note(named: name) != nil {
                NoteEditor(noteName: name)
                    .id(name)
                    .toolbar {
                        ToolbarItem {
                            Button {
                                overlays.toggleOverlay(for: name)
                            } label: {
                                Label(
                                    overlays.isOpen(name) ? "Hide Overlay" : "Float on Top",
                                    systemImage: overlays.isOpen(name) ? "eye.slash" : "eye"
                                )
                            }
                            .help(overlays.isOpen(name)
                                  ? "Hide the floating overlay"
                                  : "Float this note above all windows — invisible to screen sharing")
                        }
                    }
            } else {
                ContentUnavailableView(
                    "No Note Selected",
                    systemImage: "note.text",
                    description: Text("Select a note in the sidebar, or create one.")
                )
            }
        }
        .onAppear { if selection == nil { selection = store.notes.first?.name } }
    }

    @ViewBuilder
    private func row(for note: Note) -> some View {
        if editingNote == note.name {
            TextField("Name", text: $pendingName)
                .textFieldStyle(.plain)
                .focused($renameFieldFocused)
                .onSubmit { commitRename() }
                .onExitCommand {
                    editingNote = nil
                    renameFieldFocused = false
                }
        } else {
            HStack {
                Text(note.name)
                Spacer()
                if overlays.isOpen(note.name) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.accentColor)
                        .help("Currently floating on screen")
                }
            }
            .contentShape(Rectangle())
            .highPriorityGesture(TapGesture(count: 2).onEnded { startRename(note.name) })
            .contextMenu {
                Button(overlays.isOpen(note.name) ? "Hide Overlay" : "Float on Top") {
                    overlays.toggleOverlay(for: note.name)
                }
                Divider()
                Button("Rename") { startRename(note.name) }
                Button("Delete", role: .destructive) { delete(note.name) }
            }
        }
    }

    private func createNote() {
        let name = store.create(named: "New Note")
        selection = name
        startRename(name)
    }

    private func startRename(_ name: String) {
        pendingName = name
        editingNote = name
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { renameFieldFocused = true }
    }

    private func commitRename() {
        guard let name = editingNote else { return }
        editingNote = nil
        renameFieldFocused = false
        let wasOpen = overlays.isOpen(name)
        if wasOpen { overlays.close(name) }
        if let newName = store.rename(name, to: pendingName) {
            selection = newName
            if wasOpen { overlays.open(newName) }
        } else if wasOpen {
            overlays.open(name)
        }
    }

    private func delete(_ name: String) {
        overlays.close(name)
        store.delete(name)
        if selection == name { selection = store.notes.first?.name }
    }
}

struct NoteEditor: View {
    let noteName: String
    @EnvironmentObject var store: NotesStore
    @State private var text = ""

    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 14))
            .scrollContentBackground(.hidden)
            .padding(8)
            .navigationTitle(noteName)
            .onAppear { text = store.note(named: noteName)?.text ?? "" }
            .onChange(of: text) { _, newValue in
                store.update(name: noteName, text: newValue)
            }
    }
}

// MARK: - Settings

struct HotKeyOption {
    let title: String
    let keyCode: UInt32
    let modifiers: UInt32
}

let hotKeyOptions: [HotKeyOption] = [
    HotKeyOption(title: "⌃⌥N", keyCode: UInt32(kVK_ANSI_N), modifiers: UInt32(controlKey | optionKey)),
    HotKeyOption(title: "⌃⌥Space", keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | optionKey)),
    HotKeyOption(title: "⌘\\", keyCode: UInt32(kVK_ANSI_Backslash), modifiers: UInt32(cmdKey)),
    HotKeyOption(title: "⌃⌥⌘H", keyCode: UInt32(kVK_ANSI_H), modifiers: UInt32(controlKey | optionKey | cmdKey)),
    HotKeyOption(title: "F13", keyCode: UInt32(kVK_F13), modifiers: 0),
]

struct SettingsView: View {
    var body: some View {
        TabView {
            AppearanceSettings()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            ShortcutSettings()
                .tabItem { Label("Shortcut", systemImage: "keyboard") }
        }
        .frame(width: 400)
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct AppearanceSettings: View {
    @AppStorage(SettingsKeys.theme) private var themeRaw = ThemePreset.dark.rawValue
    @AppStorage(SettingsKeys.font) private var fontRaw = FontPreset.system.rawValue
    @AppStorage(SettingsKeys.fontSize) private var fontSize = 16.0
    @AppStorage(SettingsKeys.opacity) private var opacity = 0.85

    var body: some View {
        Form {
            Picker("Theme", selection: $themeRaw) {
                ForEach(ThemePreset.allCases) { Text($0.title).tag($0.rawValue) }
            }
            Picker("Font", selection: $fontRaw) {
                ForEach(FontPreset.allCases) { Text($0.title).tag($0.rawValue) }
            }
            Picker("Text Size", selection: $fontSize) {
                ForEach([13.0, 16.0, 20.0, 24.0, 28.0], id: \.self) { Text("\(Int($0)) pt").tag($0) }
            }
            Slider(value: $opacity, in: 0.3...1.0, step: 0.05) {
                Text("Opacity")
            } minimumValueLabel: {
                Image(systemName: "circle.dotted")
            } maximumValueLabel: {
                Image(systemName: "circle.fill")
            }
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
    }
}

struct ShortcutSettings: View {
    @AppStorage(SettingsKeys.hotKey) private var hotKeyIndex = 0

    var body: some View {
        Form {
            Picker("Show/hide all overlays", selection: $hotKeyIndex) {
                ForEach(hotKeyOptions.indices, id: \.self) { Text(hotKeyOptions[$0].title).tag($0) }
            }
            .onChange(of: hotKeyIndex) { _, newValue in
                HotKeyCenter.shared.register(optionIndex: newValue)
            }
            Text("Works globally, even when another app is active.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
    }
}

// MARK: - Global hotkey

final class HotKeyCenter {
    static let shared = HotKeyCenter()
    private var hotKeyRef: EventHotKeyRef?
    private var handlerInstalled = false

    func register(optionIndex: Int) {
        let option = hotKeyOptions.indices.contains(optionIndex) ? hotKeyOptions[optionIndex] : hotKeyOptions[0]
        if let existing = hotKeyRef {
            UnregisterEventHotKey(existing)
            hotKeyRef = nil
        }
        if !handlerInstalled {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ -> OSStatus in
                DispatchQueue.main.async { OverlayManager.shared.toggleAllVisibility() }
                return noErr
            }, 1, &eventType, nil, nil)
            handlerInstalled = true
        }
        let hotKeyID = EventHotKeyID(signature: OSType(0x534E_5453), id: 1) // "SNTS"
        RegisterEventHotKey(option.keyCode, option.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}

// MARK: - App

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
