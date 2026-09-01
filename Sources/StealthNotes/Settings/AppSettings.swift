import SwiftUI
import AppKit
import Carbon.HIToolbox

enum SettingsKeys {
    static let theme = "themePreset"
    static let font = "fontPreset"
    static let sizePreset = "overlaySizePreset"
    static let dim = "overlayDim"
    static let backgroundOpacity = "overlayBackgroundOpacity"
    static let contentOpacity = "overlayContentOpacity"
    static let hotKey = "hotKeyIndex"
    static let passThrough = "passThroughByDefault"
    static let renderMarkdown = "renderMarkdownInOverlays"
    static let editorHighlight = "editorSyntaxHighlight"
    static let holdKey = "holdKeyIndex"
}

/// Overlays use the system HUD material; the "theme" is just its light/dark flavor.
enum ThemePreset: String, CaseIterable, Identifiable {
    case dark, light
    var id: String { rawValue }

    /// Tolerant of legacy stored values (midnight/sepia/matrix from earlier versions).
    static func from(_ raw: String) -> ThemePreset {
        switch raw {
        case "light", "sepia": return .light
        default: return .dark
        }
    }

    var title: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }
    var text: Color {
        switch self {
        case .dark: return .white.opacity(0.96)
        case .light: return .black.opacity(0.9)
        }
    }
    var appearanceName: NSAppearance.Name { self == .light ? .aqua : .darkAqua }
    var isLight: Bool { self == .light }
}

/// Presenter-oriented text sizes instead of raw point values.
enum SizePreset: String, CaseIterable, Identifiable {
    case compact, regular, stage
    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact: return "Compact"
        case .regular: return "Regular"
        case .stage: return "Stage"
        }
    }
    var size: CGFloat {
        switch self {
        case .compact: return 14
        case .regular: return 16
        case .stage: return 21
        }
    }
    var lineSpacing: CGFloat {
        switch self {
        case .compact: return 3
        case .regular: return 5
        case .stage: return 7
        }
    }
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
    /// Global hardware modifier state — readable even while another app is frontmost,
    /// unlike NSEvent.modifierFlags which only updates from our own event stream.
    let cgFlags: CGEventFlags
}

// Note: options containing Control are poor defaults — macOS turns ⌃+click into a
// right-click, which breaks dragging the overlay while the key is held.
let holdKeyOptions: [HoldKeyOption] = [
    HoldKeyOption(title: "⌘ Command", cgFlags: .maskCommand),
    HoldKeyOption(title: "⌥ Option", cgFlags: .maskAlternate),
    HoldKeyOption(title: "Fn (Globe)", cgFlags: .maskSecondaryFn),
    HoldKeyOption(title: "⌃ Control", cgFlags: .maskControl),
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
