import AppKit

@MainActor
final class ArrivalIndicatorController {
    private let panel: NSPanel
    private var hideWorkItem: DispatchWorkItem?

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 22, height: 22),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let indicator = NSView(frame: NSRect(x: 3, y: 3, width: 16, height: 16))
        indicator.wantsLayer = true
        indicator.layer?.cornerRadius = 8
        indicator.layer?.borderWidth = 2
        indicator.layer?.borderColor = NSColor.controlAccentColor.cgColor
        indicator.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.22).cgColor
        panel.contentView = indicator
    }

    func show(at coreGraphicsPoint: CGPoint) {
        hideWorkItem?.cancel()
        let mainTop = NSScreen.screens.first?.frame.maxY ?? 0
        let appKitPoint = CGPoint(x: coreGraphicsPoint.x, y: mainTop - coreGraphicsPoint.y)
        panel.setFrameOrigin(NSPoint(x: appKitPoint.x - 11, y: appKitPoint.y - 11))
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.18
                self.panel.animator().alphaValue = 0
            } completionHandler: {
                self.panel.orderOut(nil)
            }
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34, execute: workItem)
    }
}
