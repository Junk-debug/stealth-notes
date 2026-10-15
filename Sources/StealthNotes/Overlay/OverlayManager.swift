import AppKit
import SwiftUI
import Combine

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
}

/// Owns the floating overlay windows: opening/closing, section paging,
/// and the hold-key click-through behavior.
final class OverlayManager: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = OverlayManager()

    @Published var openNotes: Set<String> = []
    @Published var sectionIndex: [String: Int] = [:]
    /// True while the hold key is making overlays interactive — drives the "you can drag me" hint.
    @Published var dragHintActive = false
    /// True whenever overlays currently receive mouse events (any mode).
    @Published var interactive = false
    private var panels: [String: OverlayPanel] = [:]
    private var cascadeOffset: CGFloat = 0
    private var interactionTimer: Timer?

    private override init() {
        super.init()
        // Poll the physical modifier state: no accessibility permission needed,
        // unlike a global flagsChanged event monitor.
        interactionTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            self?.updateInteraction()
        }
    }

    private func updateInteraction() {
        guard !panels.isEmpty else { return }
        let defaults = UserDefaults.standard
        let passThroughByDefault = defaults.object(forKey: SettingsKeys.passThrough) as? Bool ?? true
        let holdFlags = holdKeyOption(at: defaults.integer(forKey: SettingsKeys.holdKey)).cgFlags
        let current = CGEventSource.flagsState(.combinedSessionState)
        let held = current.isSuperset(of: holdFlags)
        let ignores = (passThroughByDefault != held)
        for panel in panels.values where panel.ignoresMouseEvents != ignores {
            panel.ignoresMouseEvents = ignores
        }
        let hint = held && !ignores
        if dragHintActive != hint {
            withAnimation(.easeInOut(duration: 0.12)) { dragHintActive = hint }
        }
        if interactive != !ignores { interactive = !ignores }
    }

    /// Direction of the last page turn (+1 next / -1 previous), for the slide transition.
    @Published var pageDirection: Int = 1

    func page(_ delta: Int) {
        pageDirection = delta >= 0 ? 1 : -1
        withAnimation(.easeOut(duration: 0.15)) {
            for name in openNotes {
                let count = Markdown.sections(of: NotesStore.shared.note(named: name)?.text ?? "").count
                guard count > 1 else { continue }
                let current = sectionIndex[name] ?? 0
                sectionIndex[name] = min(max(current + delta, 0), count - 1)
            }
        }
    }

    func isOpen(_ name: String) -> Bool { openNotes.contains(name) }

    func toggleOverlay(for name: String) {
        if isOpen(name) { close(name) } else { open(name) }
    }

    func open(_ name: String) {
        guard panels[name] == nil else {
            panels[name]?.orderFrontRegardless()
            return
        }
        let panel = OverlayPanel(
            contentRect: NSRect(x: 120 + cascadeOffset, y: 300 - cascadeOffset, width: 320, height: 340),
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        cascadeOffset = (cascadeOffset + 28).truncatingRemainder(dividingBy: 140)
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        // The whole point: exclude overlays from screen capture / sharing / recording.
        panel.sharingType = .none

        let host = NSHostingView(rootView: OverlayView(noteName: name).environmentObject(NotesStore.shared))
        panel.contentView = host
        panel.setFrameAutosaveName("overlay-\(name)")
        panel.orderFrontRegardless()

        panels[name] = panel
        openNotes.insert(name)
    }

    func close(_ name: String) {
        panels[name]?.close()
    }

    func closeAll() {
        for name in Array(openNotes) { close(name) }
    }

    func windowWillClose(_ notification: Notification) {
        guard let panel = notification.object as? OverlayPanel,
              let name = panels.first(where: { $0.value === panel })?.key else { return }
        panels.removeValue(forKey: name)
        openNotes.remove(name)
    }

    func toggleAllVisibility() {
        guard !panels.isEmpty else { return }
        let anyVisible = panels.values.contains { $0.isVisible }
        for panel in panels.values {
            if anyVisible { panel.orderOut(nil) } else { panel.orderFrontRegardless() }
        }
    }
}
