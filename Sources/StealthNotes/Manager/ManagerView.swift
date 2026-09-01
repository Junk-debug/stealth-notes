import SwiftUI
import UniformTypeIdentifiers

/// Main window: sidebar with notes, editor detail, markdown import via button or drag&drop.
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
                    Menu {
                        Button("New Note", action: createNote)
                        Button("Import Markdown…") { showImporter = true }
                    } label: {
                        Label("New Note", systemImage: "square.and.pencil")
                    } primaryAction: {
                        createNote()
                    }
                    .help("New note — open the menu to import Markdown (or just drop files into the window)")
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
