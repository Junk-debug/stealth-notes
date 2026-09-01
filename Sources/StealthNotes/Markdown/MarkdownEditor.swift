import SwiftUI
import AppKit

/// NSTextView-backed editor with lightweight markdown syntax highlighting.
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
