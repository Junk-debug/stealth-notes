import SwiftUI
import AppKit
import Carbon.HIToolbox
import UniformTypeIdentifiers

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

    /// Imports a .md/.txt file as a new note named after the file. Returns the note name.
    @discardableResult
    func importFile(at url: URL) -> String? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return create(named: url.deletingPathExtension().lastPathComponent, text: text)
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
    case jetbrains, system, rounded, serif, mono
    var id: String { rawValue }
    var title: String {
        switch self {
        case .jetbrains: return "JetBrains Mono"
        case .system: return "System"
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        case .mono: return "SF Mono"
        }
    }
    var design: Font.Design {
        switch self {
        case .system: return .default
        case .rounded: return .rounded
        case .serif: return .serif
        case .mono, .jetbrains: return .monospaced
        }
    }
    static let jetBrainsInstalled = NSFont(name: "JetBrainsMono-Regular", size: 12) != nil

    func font(size: CGFloat) -> Font {
        if self == .jetbrains, Self.jetBrainsInstalled {
            return .custom("JetBrainsMono-Regular", size: size)
        }
        return .system(size: size, design: design)
    }
}

enum SettingsKeys {
    static let theme = "themePreset"
    static let font = "fontPreset"
    static let fontSize = "overlayFontSize"
    static let opacity = "overlayOpacity"
    static let hotKey = "hotKeyIndex"
    static let passThrough = "passThroughByDefault"
    static let renderMarkdown = "renderMarkdownInOverlays"
    static let editorHighlight = "editorSyntaxHighlight"
    static let holdKey = "holdKeyIndex"
}

struct HoldKeyOption {
    let title: String
    let flags: NSEvent.ModifierFlags
}

let holdKeyOptions: [HoldKeyOption] = [
    HoldKeyOption(title: "⌃⌥ (Control + Option)", flags: [.control, .option]),
    HoldKeyOption(title: "Fn (Globe)", flags: .function),
    HoldKeyOption(title: "⌃ Control", flags: .control),
    HoldKeyOption(title: "⌥ Option", flags: .option),
    HoldKeyOption(title: "⌘ Command", flags: .command),
]

// MARK: - Markdown

enum MDBlock {
    case heading(String, Int)
    case bullet(String)
    case numbered(String, String)
    case quote(String)
    case code(String)
    case paragraph(String)
    case blank
}

enum Markdown {
    /// Notes are split into presentation sections by lines containing only `---`.
    static func sections(of text: String) -> [String] {
        var groups: [[String]] = [[]]
        for line in text.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                groups.append([])
            } else {
                groups[groups.count - 1].append(line)
            }
        }
        let sections = groups
            .map { $0.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return sections.isEmpty ? [text] : sections
    }

    static func blocks(of text: String) -> [MDBlock] {
        var result: [MDBlock] = []
        var codeLines: [String]? = nil
        for raw in text.components(separatedBy: "\n") {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if let lines = codeLines {
                    result.append(.code(lines.joined(separator: "\n")))
                    codeLines = nil
                } else {
                    codeLines = []
                }
                continue
            }
            if codeLines != nil {
                codeLines!.append(raw)
                continue
            }
            if trimmed.isEmpty { result.append(.blank); continue }
            if trimmed.hasPrefix("### ") { result.append(.heading(String(trimmed.dropFirst(4)), 3)); continue }
            if trimmed.hasPrefix("## ") { result.append(.heading(String(trimmed.dropFirst(3)), 2)); continue }
            if trimmed.hasPrefix("# ") { result.append(.heading(String(trimmed.dropFirst(2)), 1)); continue }
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") { result.append(.bullet(String(trimmed.dropFirst(2)))); continue }
            if trimmed.hasPrefix("> ") { result.append(.quote(String(trimmed.dropFirst(2)))); continue }
            if let dot = trimmed.firstIndex(of: "."),
               !trimmed.hasPrefix("."),
               trimmed[..<dot].allSatisfy(\.isNumber),
               trimmed.index(after: dot) < trimmed.endIndex,
               trimmed[trimmed.index(after: dot)] == " " {
                result.append(.numbered(String(trimmed[trimmed.index(dot, offsetBy: 2)...]), String(trimmed[..<dot])))
                continue
            }
            result.append(.paragraph(trimmed))
        }
        if let lines = codeLines, !lines.isEmpty { result.append(.code(lines.joined(separator: "\n"))) }
        return result
    }

    static func inline(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(s)
    }
}

struct MarkdownBody: View {
    let text: String
    let baseSize: CGFloat
    let fontPreset: FontPreset
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(Markdown.blocks(of: text).enumerated()), id: \.offset) { _, block in
                render(block)
            }
        }
    }

    @ViewBuilder
    private func render(_ block: MDBlock) -> some View {
        switch block {
        case .heading(let s, let level):
            let scale: CGFloat = level == 1 ? 1.45 : (level == 2 ? 1.25 : 1.1)
            Text(Markdown.inline(s))
                .font(fontPreset.font(size: baseSize * scale))
                .fontWeight(.bold)
                .foregroundStyle(color)
                .padding(.top, 4)
        case .bullet(let s):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•").font(fontPreset.font(size: baseSize)).foregroundStyle(color.opacity(0.6))
                Text(Markdown.inline(s)).font(fontPreset.font(size: baseSize)).foregroundStyle(color)
            }
        case .numbered(let s, let n):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(n).").font(fontPreset.font(size: baseSize)).foregroundStyle(color.opacity(0.6))
                Text(Markdown.inline(s)).font(fontPreset.font(size: baseSize)).foregroundStyle(color)
            }
        case .quote(let s):
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5).fill(color.opacity(0.3)).frame(width: 3)
                Text(Markdown.inline(s)).font(fontPreset.font(size: baseSize)).italic().foregroundStyle(color.opacity(0.85))
            }
        case .code(let s):
            Text(s)
                .font(FontPreset.jetbrains.font(size: baseSize * 0.9))
                .foregroundStyle(color)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        case .paragraph(let s):
            Text(Markdown.inline(s)).font(fontPreset.font(size: baseSize)).foregroundStyle(color)
        case .blank:
            Spacer().frame(height: baseSize * 0.4)
        }
    }
}

// MARK: - Overlay windows

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
}

final class OverlayManager: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = OverlayManager()

    @Published var openNotes: Set<String> = []
    @Published var sectionIndex: [String: Int] = [:]
    private var panels: [String: OverlayPanel] = [:]
    private var cascadeOffset: CGFloat = 0
    private var interactionTimer: Timer?

    private override init() {
        super.init()
        // Poll the physical modifier state: no accessibility permission needed,
        // unlike a global flagsChanged event monitor.
        interactionTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            self?.updateInteraction()
        }
    }

    private func updateInteraction() {
        guard !panels.isEmpty else { return }
        let defaults = UserDefaults.standard
        let passThroughByDefault = defaults.object(forKey: SettingsKeys.passThrough) as? Bool ?? true
        let idx = defaults.integer(forKey: SettingsKeys.holdKey)
        let holdFlags = holdKeyOptions.indices.contains(idx) ? holdKeyOptions[idx].flags : holdKeyOptions[0].flags
        let held = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask).isSuperset(of: holdFlags)
        let ignores = (passThroughByDefault != held)
        for panel in panels.values where panel.ignoresMouseEvents != ignores {
            panel.ignoresMouseEvents = ignores
        }
    }

    func page(_ delta: Int) {
        for name in openNotes {
            let count = Markdown.sections(of: NotesStore.shared.note(named: name)?.text ?? "").count
            guard count > 1 else { continue }
            let current = sectionIndex[name] ?? 0
            sectionIndex[name] = min(max(current + delta, 0), count - 1)
        }
    }

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
    @AppStorage(SettingsKeys.renderMarkdown) private var renderMarkdown = true
    @State private var hovering = false

    private var theme: ThemePreset { ThemePreset(rawValue: themeRaw) ?? .dark }
    private var fontPreset: FontPreset { FontPreset(rawValue: fontRaw) ?? .system }

    @ObservedObject private var overlays = OverlayManager.shared

    private var sections: [String] {
        Markdown.sections(of: store.note(named: noteName)?.text ?? "")
    }
    private var currentSection: Int {
        min(overlays.sectionIndex[noteName] ?? 0, sections.count - 1)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ScrollView {
                    Group {
                        if renderMarkdown {
                            MarkdownBody(
                                text: sections[currentSection],
                                baseSize: fontSize,
                                fontPreset: fontPreset,
                                color: theme.text
                            )
                        } else {
                            Text(sections[currentSection])
                                .font(fontPreset.font(size: fontSize))
                                .foregroundStyle(theme.text)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.top, 30)
                    .padding(.bottom, 12)
                }
                if sections.count > 1 {
                    HStack(spacing: 5) {
                        ForEach(0..<sections.count, id: \.self) { i in
                            Circle()
                                .fill(theme.text.opacity(i == currentSection ? 0.75 : 0.22))
                                .frame(width: 6, height: 6)
                                .onTapGesture { overlays.sectionIndex[noteName] = i }
                        }
                    }
                    .padding(.bottom, 8)
                }
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
    @State private var showImporter = false
    @State private var isDropTargeted = false
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
                ToolbarItem {
                    Button { showImporter = true } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .help("Import Markdown or text files (or just drop them into the window)")
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
        .fileImporter(isPresented: $showImporter, allowedContentTypes: importTypes, allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { importFiles(urls) }
        }
        .dropDestination(for: URL.self) { urls, _ in
            let files = urls.filter { ["md", "markdown", "txt"].contains($0.pathExtension.lowercased()) }
            guard !files.isEmpty else { return false }
            importFiles(files)
            return true
        } isTargeted: { isDropTargeted = $0 }
        .overlay {
            if isDropTargeted {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8, 5]))
                        .padding(12)
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                        Text("Drop Markdown to import")
                            .font(.title3.weight(.semibold))
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
    }

    private var importTypes: [UTType] {
        var types: [UTType] = [.plainText]
        if let md = UTType(filenameExtension: "md") { types.append(md) }
        if let markdown = UTType(filenameExtension: "markdown") { types.append(markdown) }
        return types
    }

    private func importFiles(_ urls: [URL]) {
        var lastImported: String?
        for url in urls {
            if let name = store.importFile(at: url) { lastImported = name }
        }
        if let name = lastImported { selection = name }
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
    @AppStorage(SettingsKeys.editorHighlight) private var highlight = true
    @State private var text = ""
    @State private var previewing = false

    var body: some View {
        Group {
            if previewing {
                ScrollView {
                    MarkdownBody(text: text, baseSize: 15, fontPreset: .system, color: Color(nsColor: .labelColor))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
                .contentShape(Rectangle())
                .onTapGesture { previewing = false }
                .help("Click to edit")
            } else {
                MarkdownEditor(text: $text, highlightEnabled: highlight)
                    .padding(4)
            }
        }
        .navigationTitle(noteName)
        .toolbar {
            ToolbarItem {
                Picker("Mode", selection: $previewing) {
                    Text("Edit").tag(false)
                    Text("Preview").tag(true)
                }
                .pickerStyle(.segmented)
                .help("Switch between editing and rendered preview (⌘E)")
            }
        }
        .background(
            Button("") { previewing.toggle() }
                .keyboardShortcut("e", modifiers: .command)
                .hidden()
        )
        .onAppear { text = store.note(named: noteName)?.text ?? "" }
        .onChange(of: text) { _, newValue in
            store.update(name: noteName, text: newValue)
        }
    }
}

// MARK: - Markdown editor (NSTextView with lightweight syntax highlighting)

struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    var highlightEnabled: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        let textView = scroll.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.drawsBackground = false
        scroll.drawsBackground = false
        textView.string = text
        context.coordinator.highlight(textView)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let textView = scroll.documentView as! NSTextView
        context.coordinator.parent = self
        if textView.string != text {
            textView.string = text
            context.coordinator.highlight(textView)
        } else if context.coordinator.lastHighlightEnabled != highlightEnabled {
            context.coordinator.highlight(textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditor
        var lastHighlightEnabled: Bool?

        init(_ parent: MarkdownEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            highlight(textView)
        }

        private static let baseFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        private static let boldFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)
        private static let italicFont: NSFont =
            NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)

        func highlight(_ textView: NSTextView) {
            lastHighlightEnabled = parent.highlightEnabled
            guard let storage = textView.textStorage else { return }
            let full = NSRange(location: 0, length: storage.length)
            storage.beginEditing()
            storage.setAttributes([
                .font: Self.baseFont,
                .foregroundColor: NSColor.labelColor,
            ], range: full)

            if parent.highlightEnabled {
                func apply(_ pattern: String, _ attrs: [NSAttributedString.Key: Any], group: Int = 0) {
                    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return }
                    regex.enumerateMatches(in: storage.string, range: full) { match, _, _ in
                        guard let match else { return }
                        let range = match.range(at: group)
                        if range.location != NSNotFound { storage.addAttributes(attrs, range: range) }
                    }
                }

                let accent = NSColor.controlAccentColor
                let secondary = NSColor.secondaryLabelColor
                let codeBackground = NSColor.labelColor.withAlphaComponent(0.07)

                apply(#"^#{1,3} .*$"#, [.font: Self.boldFont])
                apply(#"^(#{1,3}) "#, [.foregroundColor: accent], group: 1)
                apply(#"^\s*([-*]) "#, [.foregroundColor: accent], group: 1)
                apply(#"^\s*(\d+\.) "#, [.foregroundColor: accent], group: 1)
                apply(#"^> .*$"#, [.foregroundColor: secondary])
                apply(#"\*\*[^*\n]+\*\*"#, [.font: Self.boldFont])
                apply(#"(?<![*\w])\*[^*\n]+\*(?!\*)"#, [.font: Self.italicFont])
                apply(#"`[^`\n]+`"#, [.backgroundColor: codeBackground])
                apply(#"^---$"#, [.foregroundColor: accent])
                apply(#"^```.*$"#, [.foregroundColor: secondary])
            }
            storage.endEditing()
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
            BehaviorSettings()
                .tabItem { Label("Behavior", systemImage: "cursorarrow.rays") }
            ShortcutSettings()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .frame(width: 400)
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct BehaviorSettings: View {
    @AppStorage(SettingsKeys.passThrough) private var passThroughByDefault = true
    @AppStorage(SettingsKeys.holdKey) private var holdKeyIndex = 0

    private var holdTitle: String { holdKeyOptions[holdKeyIndex].title.components(separatedBy: " ").first ?? "" }

    var body: some View {
        Form {
            Picker("Overlay mouse behavior", selection: $passThroughByDefault) {
                Text("Click-through — hold \(holdTitle) to interact").tag(true)
                Text("Interactive — hold \(holdTitle) to click through").tag(false)
            }
            .pickerStyle(.radioGroup)
            Picker("Hold key", selection: $holdKeyIndex) {
                ForEach(holdKeyOptions.indices, id: \.self) { Text(holdKeyOptions[$0].title).tag($0) }
            }
            Text("Click-through overlays never steal clicks: everything passes to the window below. Hold the key above to temporarily flip the behavior — drag, scroll or close the overlay, then release.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
    }
}

struct AppearanceSettings: View {
    @AppStorage(SettingsKeys.theme) private var themeRaw = ThemePreset.dark.rawValue
    @AppStorage(SettingsKeys.font) private var fontRaw = FontPreset.system.rawValue
    @AppStorage(SettingsKeys.fontSize) private var fontSize = 16.0
    @AppStorage(SettingsKeys.opacity) private var opacity = 0.85
    @AppStorage(SettingsKeys.renderMarkdown) private var renderMarkdown = true
    @AppStorage(SettingsKeys.editorHighlight) private var editorHighlight = true

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
            Section {
                Toggle("Render Markdown in overlays", isOn: $renderMarkdown)
                Toggle("Markdown syntax highlighting in editor", isOn: $editorHighlight)
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
            LabeledContent("Next section", value: "⌃⌥→")
            LabeledContent("Previous section", value: "⌃⌥←")
            Text("All shortcuts work globally, even when another app is active. Split a note into sections with a line containing only ---.")
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
    private var refs: [EventHotKeyRef?] = []
    private var handlerInstalled = false

    func register(optionIndex: Int) {
        let option = hotKeyOptions.indices.contains(optionIndex) ? hotKeyOptions[optionIndex] : hotKeyOptions[0]
        for ref in refs { if let ref { UnregisterEventHotKey(ref) } }
        refs.removeAll()

        if !handlerInstalled {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
                var hkID = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                  nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
                DispatchQueue.main.async {
                    switch hkID.id {
                    case 1: OverlayManager.shared.toggleAllVisibility()
                    case 2: OverlayManager.shared.page(1)
                    case 3: OverlayManager.shared.page(-1)
                    default: break
                    }
                }
                return noErr
            }, 1, &eventType, nil, nil)
            handlerInstalled = true
        }

        let signature = OSType(0x534E_5453) // "SNTS"
        var toggleRef: EventHotKeyRef?
        RegisterEventHotKey(option.keyCode, option.modifiers, EventHotKeyID(signature: signature, id: 1), GetApplicationEventTarget(), 0, &toggleRef)
        var nextRef: EventHotKeyRef?
        RegisterEventHotKey(UInt32(kVK_RightArrow), UInt32(controlKey | optionKey), EventHotKeyID(signature: signature, id: 2), GetApplicationEventTarget(), 0, &nextRef)
        var prevRef: EventHotKeyRef?
        RegisterEventHotKey(UInt32(kVK_LeftArrow), UInt32(controlKey | optionKey), EventHotKeyID(signature: signature, id: 3), GetApplicationEventTarget(), 0, &prevRef)
        refs = [toggleRef, nextRef, prevRef]
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
