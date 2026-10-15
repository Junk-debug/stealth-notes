<p align="center">
  <img src="docs/icon.png" width="128" alt="Stealth Notes icon">
</p>

<h1 align="center">Stealth Notes</h1>

<p align="center">
  Speaker notes that float above your slides — and stay off the shared screen.<br>
  A small native macOS app built with SwiftUI + AppKit.
</p>

<p align="center">
  <a href="https://github.com/Junk-debug/stealth-notes/actions/workflows/ci.yml"><img src="https://github.com/Junk-debug/stealth-notes/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift 5.9">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="MIT license"></a>
</p>

## Why

When you present over Zoom, Meet or Teams with a single screen, your notes have nowhere to go: put them in a window and the audience sees them too, put them on paper and you keep looking away. Stealth Notes is a teleprompter-style overlay for that situation — your notes float above the slides (full-screen apps included), and the windows are flagged so screen sharing leaves them out.

## Features

- **Floating overlays** — borderless cards above every window and Space, including full-screen apps. Open several notes at once; each remembers its position and size.
- **Kept out of screen sharing** — overlays use `NSWindow.sharingType = .none`, which conferencing apps and screenshots respect. See [Limitations](#limitations) for what this does *not* cover.
- **Sections for talks** — split a note with a line containing only `---` and page through it with global hotkeys (`⌃⌥→` / `⌃⌥←`). The overlay shows a progress bar, dots and the current step's heading.
- **Click-through by default** — overlays never steal clicks from your slides. Hold a key (⌘ by default) to drag, scroll or close them; the border lights up while they are interactive. No Accessibility permission is required.
- **Markdown** — headings, lists, quotes, inline styles and code blocks render in overlays; the editor has syntax highlighting and an Edit ⇄ Preview toggle (`⌘E`).
- **Plain files** — notes are `.txt` files in `~/Library/Application Support/StealthNotes/Notes/`, saved as you type. Import `.md` / `.txt` with the button or by dropping files onto the window.
- **Native UI** — sidebar manager window, menu bar item, standard Settings window (appearance, text size, background/text opacity, fonts including bundled JetBrains Mono).

## Install

Requires **macOS 14 Sonoma or later** and Xcode (or the Xcode Command Line Tools) with Swift 5.9+.

```bash
git clone https://github.com/Junk-debug/stealth-notes.git
cd stealth-notes
./build.sh --install
```

`./build.sh` builds `Stealth Notes.app` in the repo folder; `--install` also copies it to `/Applications`.

The app is ad-hoc signed, not notarized. On first launch macOS will refuse to open it: right-click the app → **Open**, or allow it in **System Settings → Privacy & Security**.

## Usage

1. Open **Stealth Notes** and write your notes in the editor (Markdown works).
2. Separate the parts of your talk with `---` lines.
3. Click the **eye** button in the toolbar (or use the menu bar icon) to float the note.
4. Start sharing and page through sections with `⌃⌥→` / `⌃⌥←`.

| Shortcut | Action | Scope |
| --- | --- | --- |
| `⌃⌥N` *(configurable)* | Show / hide all overlays | Global |
| `⌃⌥→` / `⌃⌥←` | Next / previous section | Global |
| Hold `⌘` *(configurable)* | Make overlays interactive (or click-through, if you flip the mode) | Global |
| `⌘N` | New note | Manager window |
| `⌘E` | Toggle Edit / Preview | Manager window |

## Limitations

- `sharingType = .none` is a request to capture APIs, not a guarantee. Video-call apps generally respect it, but behavior depends on the capturing app and macOS version — some tools that use ScreenCaptureKit directly (e.g. QuickTime or OBS display capture) have been reported to record such windows on macOS 15. **Do a test share before a real talk.**
- It only affects software capture on this Mac. A camera pointed at the screen sees everything.
- Global hotkeys can clash with other apps that register the same combination; pick another one in Settings if a shortcut does nothing.

## Intended use

Stealth Notes is built for presenters: talks, demos, webinars, recorded walkthroughs — situations where speaker notes are normal and expected. Please don't use it where outside notes are not allowed, such as exams, proctored tests or interviews that ask you not to use them.

## How it works

The interesting parts, if you are reading the code:

- **Overlay windows** (`Overlay/OverlayManager.swift`) — non-activating `NSPanel`s at `.statusBar` level with `.canJoinAllSpaces` + `.fullScreenAuxiliary`, so they sit above full-screen apps without taking focus from them.
- **Hold-to-interact without Accessibility permission** — instead of a global `flagsChanged` monitor (which needs the permission), a timer polls `CGEventSource.flagsState(.combinedSessionState)` and toggles `ignoresMouseEvents` on the panels.
- **Global hotkeys** (`Support/HotKeyCenter.swift`) — Carbon `RegisterEventHotKey`, which works while other apps are frontmost and needs no permissions.
- **Markdown** (`Markdown/`) — a small line-based parser feeding SwiftUI views for overlays, and regex highlighting on an `NSTextView` for the editor.
- **No Xcode project** — it is a plain Swift package; `build.sh` assembles the `.app` bundle (binary, `Info.plist`, icon, fonts loaded via `ATSApplicationFontsPath`) and ad-hoc signs it.

## Project layout

```
Package.swift            Swift Package Manager manifest
build.sh                 builds, signs and optionally installs Stealth Notes.app
Sources/StealthNotes/
  App/                   @main app, scenes, menu bar
  Models/                Note + NotesStore (plain .txt files on disk)
  Manager/               main window: sidebar, editor, import
  Overlay/               floating panels, click-through logic, overlay view
  Markdown/              parser, SwiftUI renderer, highlighting editor
  Settings/              presets, option lists, settings tabs
  Support/               Carbon global hotkeys, blur background
Tests/StealthNotesTests/ unit tests for the Markdown parser
Resources/               Info.plist, AppIcon.icns, bundled fonts
```

## Development

```bash
swift build      # debug build
swift test       # run unit tests
./build.sh       # release .app bundle
```

You can also open `Package.swift` in Xcode to edit and run the app with the debugger.

## License

[MIT](LICENSE). JetBrains Mono is bundled under the [SIL Open Font License](Resources/Fonts/OFL.txt).
