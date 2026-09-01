import SwiftUI

/// Content of a floating overlay: rendered note (or raw text), section dots, hover header.
struct OverlayView: View {
    let noteName: String
    @EnvironmentObject var store: NotesStore
    @ObservedObject private var overlays = OverlayManager.shared
    @AppStorage(SettingsKeys.theme) private var themeRaw = ThemePreset.dark.rawValue
    @AppStorage(SettingsKeys.font) private var fontRaw = FontPreset.system.rawValue
    @AppStorage(SettingsKeys.fontSize) private var fontSize = 16.0
    @AppStorage(SettingsKeys.opacity) private var opacity = 0.85
    @AppStorage(SettingsKeys.renderMarkdown) private var renderMarkdown = true
    @State private var hovering = false

    private var theme: ThemePreset { ThemePreset(rawValue: themeRaw) ?? .dark }
    private var fontPreset: FontPreset { FontPreset(rawValue: fontRaw) ?? .system }

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
