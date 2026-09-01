import SwiftUI

/// Content of a floating overlay: rendered note on a system HUD material,
/// section paging with slide transitions, hover header with counter and close.
struct OverlayView: View {
    let noteName: String
    @EnvironmentObject var store: NotesStore
    @ObservedObject private var overlays = OverlayManager.shared
    @AppStorage(SettingsKeys.theme) private var themeRaw = ThemePreset.dark.rawValue
    @AppStorage(SettingsKeys.font) private var fontRaw = FontPreset.system.rawValue
    @AppStorage(SettingsKeys.sizePreset) private var sizeRaw = SizePreset.regular.rawValue
    @AppStorage(SettingsKeys.dim) private var dim = 0.25
    @AppStorage(SettingsKeys.opacity) private var cardOpacity = 1.0
    @AppStorage(SettingsKeys.renderMarkdown) private var renderMarkdown = true
    @State private var hovering = false
    @State private var appeared = false

    private var theme: ThemePreset { ThemePreset.from(themeRaw) }
    private var fontPreset: FontPreset { FontPreset(rawValue: fontRaw) ?? .system }
    private var sizePreset: SizePreset { SizePreset(rawValue: sizeRaw) ?? .regular }

    private var sections: [String] {
        Markdown.sections(of: store.note(named: noteName)?.text ?? "")
    }
    private var currentSection: Int {
        min(overlays.sectionIndex[noteName] ?? 0, sections.count - 1)
    }
    /// If the current section starts with a heading, use it as the step title.
    private var sectionTitle: String? {
        if case .heading(let title, _) = Markdown.blocks(of: sections[currentSection]).first {
            return title
        }
        return nil
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ScrollView {
                    sectionContent
                        .id(currentSection)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(x: CGFloat(overlays.pageDirection) * 14)),
                            removal: .opacity.combined(with: .offset(x: CGFloat(overlays.pageDirection) * -14))
                        ))
                        .frame(maxWidth: sizePreset.size * 34, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.top, 32)
                        .padding(.bottom, 14)
                }
                if sections.count > 1 {
                    HStack(spacing: 5) {
                        ForEach(0..<sections.count, id: \.self) { i in
                            Circle()
                                .fill(theme.text.opacity(i == currentSection ? 0.75 : 0.22))
                                .frame(width: 6, height: 6)
                                .onTapGesture {
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        overlays.pageDirection = i > currentSection ? 1 : -1
                                        overlays.sectionIndex[noteName] = i
                                    }
                                }
                        }
                    }
                    .padding(.bottom, 9)
                }
            }

            // Thin progress line along the top edge.
            if sections.count > 1 {
                GeometryReader { geo in
                    Capsule()
                        .fill(theme.text.opacity(0.28))
                        .frame(width: geo.size.width * CGFloat(currentSection + 1) / CGFloat(sections.count), height: 2)
                }
                .frame(height: 2)
                .padding(.horizontal, 14)
                .padding(.top, 4)
            }

            // Header: step title (or note name), counter, close — fades in on hover.
            HStack(spacing: 6) {
                Text(sectionTitle ?? noteName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.text.opacity(0.45))
                    .lineLimit(1)
                if sections.count > 1 {
                    Text("\(currentSection + 1) / \(sections.count)")
                        .font(.system(size: 11, weight: .regular).monospacedDigit())
                        .foregroundStyle(theme.text.opacity(0.3))
                }
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
            .padding(.horizontal, 14)
            .padding(.top, 10)
        }
        .frame(minWidth: 200, minHeight: 120)
        .background {
            ZStack {
                VisualEffectBackground(appearance: theme.appearanceName)
                (theme.isLight ? Color.white : Color.black).opacity(dim)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(theme.text.opacity(0.09), lineWidth: 1)
        )
        .scaleEffect(appeared ? 1 : 0.98)
        .opacity(appeared ? cardOpacity : 0)
        .onAppear {
            withAnimation(.spring(duration: 0.22)) { appeared = true }
        }
        .onHover { hovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: hovering)
        .environment(\.colorScheme, theme.isLight ? .light : .dark)
    }

    @ViewBuilder
    private var sectionContent: some View {
        if renderMarkdown {
            MarkdownBody(
                text: sections[currentSection],
                baseSize: sizePreset.size,
                fontPreset: fontPreset,
                color: theme.text,
                lineSpacing: sizePreset.lineSpacing
            )
        } else {
            Text(sections[currentSection])
                .font(fontPreset.font(size: sizePreset.size))
                .lineSpacing(sizePreset.lineSpacing)
                .foregroundStyle(theme.text)
        }
    }
}
