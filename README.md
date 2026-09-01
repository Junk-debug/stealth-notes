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

The app icon is generated programmatically (CoreGraphics + CIGaussianBlur for the frosted-glass effect):

```bash
swift gen_icon.swift icon_1024.png        # half-frosted variant (default)
swift gen_icon.swift icon_full_1024.png full  # fully frosted variant
```

Then pack it:

```bash
mkdir AppIcon.iconset
for s in 16 32 128 256 512; do
  sips -z $s $s icon_1024.png --out AppIcon.iconset/icon_${s}x${s}.png
  sips -z $((s*2)) $((s*2)) icon_1024.png --out AppIcon.iconset/icon_${s}x${s}@2x.png
done
iconutil -c icns AppIcon.iconset -o StealthNotes.app/Contents/Resources/AppIcon.icns
```

## Requirements

macOS 14+ (SwiftUI `MenuBarExtra`, Settings scenes). No dependencies, no Xcode project — a single `main.swift`.
