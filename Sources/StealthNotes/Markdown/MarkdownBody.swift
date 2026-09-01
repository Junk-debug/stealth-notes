import SwiftUI

/// Renders a markdown string as read-only SwiftUI views. Used by overlays and the editor preview.
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
