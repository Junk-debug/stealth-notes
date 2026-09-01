# Stealth Notes

A tiny native macOS app for presenters: float your notes above every window — including full-screen slides — while staying **invisible to screen sharing, recording and screenshots** (`NSWindow.sharingType = .none`).

![icon](docs/icon.png)

## Features

- **Manager window** — native SwiftUI split view: sidebar with notes, distraction-free editor, inline rename (double-click), everything auto-saved as plain `.txt` files in `~/Library/Application Support/StealthNotes/Notes/`.
- **Overlays** — borderless rounded cards that float above all windows (full-screen apps included). Open several at once; each remembers its position. Close button appears on hover only.
- **Stealth** — overlays are excluded from screen capture: Zoom/Meet/Teams screen sharing, recordings and screenshots never see them. Only programmatic capture on this Mac is affected — a phone camera pointed at the screen still sees everything.
- **Menu bar** — toggle any note's overlay, show/hide all, or close all from the eye icon.
- **Global hotkey** — show/hide all overlays from anywhere (default ⌃⌥N, configurable).
- **Native settings** — theme, font, text size, opacity, shortcut. Standard macOS Settings tabs.

## Build

```bash
swiftc -O -parse-as-library -o StealthNotes.app/Contents/MacOS/StealthNotes main.swift -framework Cocoa -framework Carbon
cp -R StealthNotes.app "/Applications/Stealth Notes.app"
```

## Icon

The app icon ships as a static asset: `StealthNotes.app/Contents/Resources/AppIcon.icns` (preview in `docs/icon.png`). If you ever want to tweak it, `gen_icon.swift` is the script that originally drew it (CoreGraphics + CIGaussianBlur):

```bash
swift gen_icon.swift icon_1024.png   # then repack with iconutil
```

## Fonts

JetBrains Mono (OFL license) is bundled inside the app at `Contents/Resources/Fonts` and loaded via `ATSApplicationFontsPath` — no system installation required.

## Requirements

macOS 14+ (SwiftUI `MenuBarExtra`, Settings scenes). No dependencies, no Xcode project — a single `main.swift`.
