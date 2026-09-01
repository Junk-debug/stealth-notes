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
