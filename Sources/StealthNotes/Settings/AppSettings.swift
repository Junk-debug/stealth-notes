import SwiftUI
import AppKit
import Carbon.HIToolbox

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
