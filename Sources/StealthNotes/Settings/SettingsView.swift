import SwiftUI

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

struct AppearanceSettings: View {
    @AppStorage(SettingsKeys.theme) private var themeRaw = ThemePreset.dark.rawValue
    @AppStorage(SettingsKeys.font) private var fontRaw = FontPreset.system.rawValue
    @AppStorage(SettingsKeys.sizePreset) private var sizeRaw = SizePreset.regular.rawValue
    @AppStorage(SettingsKeys.dim) private var dim = 0.25
    @AppStorage(SettingsKeys.backgroundOpacity) private var backgroundOpacity = 1.0
    @AppStorage(SettingsKeys.contentOpacity) private var contentOpacity = 1.0
    @AppStorage(SettingsKeys.renderMarkdown) private var renderMarkdown = true
    @AppStorage(SettingsKeys.editorHighlight) private var editorHighlight = true

    var body: some View {
        Form {
            Picker("Appearance", selection: $themeRaw) {
                ForEach(ThemePreset.allCases) { Text($0.title).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            Picker("Font", selection: $fontRaw) {
                ForEach(FontPreset.allCases) { Text($0.title).tag($0.rawValue) }
            }
            Picker("Text Size", selection: $sizeRaw) {
                ForEach(SizePreset.allCases) { Text($0.title).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            Slider(value: $dim, in: 0.0...0.6, step: 0.05) {
                Text("Dim")
            } minimumValueLabel: {
                Image(systemName: "sun.max")
            } maximumValueLabel: {
                Image(systemName: "moon")
            }
            Slider(value: $backgroundOpacity, in: 0.0...1.0, step: 0.05) {
                Text("Background opacity")
            } minimumValueLabel: {
                Image(systemName: "square.dashed")
            } maximumValueLabel: {
                Image(systemName: "square.fill")
            }
            Slider(value: $contentOpacity, in: 0.35...1.0, step: 0.05) {
                Text("Text opacity")
            } minimumValueLabel: {
                Image(systemName: "textformat")
            } maximumValueLabel: {
                Image(systemName: "textformat.size")
            }
            Text("Overlays sit on the system HUD material — a real blur of whatever is behind them. Dim controls how much the glass is darkened. Stage size is meant to be readable from a distance.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Section {
                Toggle("Render Markdown in overlays", isOn: $renderMarkdown)
                Toggle("Markdown syntax highlighting in editor", isOn: $editorHighlight)
            }
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
    }
}

struct BehaviorSettings: View {
    @AppStorage(SettingsKeys.passThrough) private var passThroughByDefault = true
    @AppStorage(SettingsKeys.holdKey) private var holdKeyIndex = 0

    private var holdTitle: String { holdKeyOption(at: holdKeyIndex).title.components(separatedBy: " ").first ?? "" }

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
