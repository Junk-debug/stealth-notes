import SwiftUI

/// Detail view for one note: markdown editor with an Edit ⇄ Preview toggle (⌘E).
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
