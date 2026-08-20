import AppKit
import MousePortalCore

final class GlobalShortcutMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    var onToggle: () -> Void = {}
    var shortcutProvider: () -> ShortcutConfiguration = { ShortcutConfiguration() }

    func start() {
        stop()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if self.isToggleShortcut(event) {
                self.onToggle()
                return nil
            }
            return event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handle(_ event: NSEvent) {
        if isToggleShortcut(event) { onToggle() }
    }

    private func isToggleShortcut(_ event: NSEvent) -> Bool {
        let shortcut = shortcutProvider()
        let required = NSEvent.ModifierFlags(shortcut.modifiers)
        let pressed = event.modifierFlags.intersection([.control, .option, .command, .shift])
        return event.charactersIgnoringModifiers?.lowercased() == shortcut.key.lowercased()
            && pressed == required
    }
}

private extension NSEvent.ModifierFlags {
    init(_ modifiers: [ShortcutModifier]) {
        self = []
        for modifier in modifiers {
            switch modifier {
            case .control: insert(.control)
            case .option: insert(.option)
            case .command: insert(.command)
            case .shift: insert(.shift)
            }
        }
    }
}
