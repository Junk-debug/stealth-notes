import SwiftUI
import AppKit

/// System HUD material (real behind-window blur, like Spotlight / Control Center).
struct VisualEffectBackground: NSViewRepresentable {
    var appearance: NSAppearance.Name

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: appearance)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.appearance = NSAppearance(named: appearance)
    }
}
