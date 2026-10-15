import Foundation
import Combine

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
            _ = create(named: "Welcome", text: "Your presentation notes live here.\n\nClick the eye button in the toolbar to float this note above every window — including full-screen slides. Floating notes are hidden from screen sharing and screenshots.")
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

    /// Imports a .md/.txt file as a new note named after the file. Returns the note name.
    @discardableResult
    func importFile(at url: URL) -> String? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return create(named: url.deletingPathExtension().lastPathComponent, text: text)
    }

    private func sanitize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }
}
