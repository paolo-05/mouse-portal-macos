import ApplicationServices
import CoreGraphics
import Foundation
import MousePortalCore

struct EngineSnapshot {
    var displaysByUUID: [String: DisplayDescriptor]
    var portals: [Portal]
    var preferences: PortalPreferences
}

private struct PortalTransition {
    var point: CGPoint
    var delta: PointerVector
}

final class PortalEngine {
    enum State: Equatable {
        case stopped
        case needsAccessibilityPermission
        case running
        case failed(String)

        var label: String {
            switch self {
            case .stopped: "Stopped"
            case .needsAccessibilityPermission: "Accessibility permission required"
            case .running: "Active"
            case .failed(let message): message
            }
        }
    }

    var snapshotProvider: () -> EngineSnapshot
    var onStateChange: (State) -> Void = { _ in }
    var onArrival: (CGPoint) -> Void = { _ in }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastWarpTime: TimeInterval = 0
    private var lastEventTime: UInt64 = 0
    private var lastPointerLocation: PointerVector?

    init(snapshotProvider: @escaping () -> EngineSnapshot) {
        self.snapshotProvider = snapshotProvider
    }

    deinit {
        stop()
    }

    static func hasAccessibilityPermission(prompt: Bool = false) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func start(promptForPermission: Bool = false) {
        stop()

        guard Self.hasAccessibilityPermission(prompt: promptForPermission) else {
            onStateChange(.needsAccessibilityPermission)
            return
        }

        let observedTypes: [CGEventType] = [
            .mouseMoved,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged
        ]
        let mask = observedTypes.reduce(CGEventMask(0)) { partial, eventType in
            partial | (CGEventMask(1) << eventType.rawValue)
        }

        let pointer = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let engine = Unmanaged<PortalEngine>.fromOpaque(userInfo).takeUnretainedValue()
                return engine.handle(type: type, event: event)
            },
            userInfo: pointer
        ) else {
            onStateChange(.failed("Unable to create the mouse event tap"))
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        onStateChange(.running)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        lastPointerLocation = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
                onStateChange(.running)
            }
            return Unmanaged.passUnretained(event)
        }

        let point = PointerVector(x: event.location.x, y: event.location.y)
        let previousPoint = lastPointerLocation
        lastPointerLocation = point

        let snapshot = snapshotProvider()
        guard snapshot.preferences.isGloballyEnabled else {
            return Unmanaged.passUnretained(event)
        }
        guard !isSuspended(flags: event.flags, modifier: snapshot.preferences.suspendModifier) else {
            return Unmanaged.passUnretained(event)
        }

        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastWarpTime >= snapshot.preferences.cooldownSeconds else {
            return Unmanaged.passUnretained(event)
        }

        let delta = PointerVector(
            x: event.getDoubleValueField(.mouseEventDeltaX),
            y: event.getDoubleValueField(.mouseEventDeltaY)
        )

        if snapshot.preferences.minimumVelocity > 0 {
            let timestamp = event.timestamp
            defer { lastEventTime = timestamp }
            guard lastEventTime > 0, timestamp > lastEventTime else {
                return Unmanaged.passUnretained(event)
            }
            let seconds = Double(timestamp - lastEventTime) / 1_000_000_000
            guard seconds > 0, delta.magnitude / seconds >= snapshot.preferences.minimumVelocity else {
                return Unmanaged.passUnretained(event)
            }
        }

        for portal in snapshot.portals where portal.isEnabled {
            if let transition = crossingTransition(
                point: point,
                previousPoint: previousPoint,
                delta: delta,
                source: portal.source,
                destination: portal.destination,
                snapshot: snapshot
            ) {
                apply(transition, to: event, showIndicator: snapshot.preferences.showsArrivalIndicator)
                return Unmanaged.passUnretained(event)
            }

            if portal.direction == .bidirectional,
               let transition = crossingTransition(
                    point: point,
                    previousPoint: previousPoint,
                    delta: delta,
                    source: portal.destination,
                    destination: portal.source,
                    snapshot: snapshot
               ) {
                apply(transition, to: event, showIndicator: snapshot.preferences.showsArrivalIndicator)
                return Unmanaged.passUnretained(event)
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func crossingTransition(
        point: PointerVector,
        previousPoint: PointerVector?,
        delta: PointerVector,
        source: EdgeSegment,
        destination: EdgeSegment,
        snapshot: EngineSnapshot
    ) -> PortalTransition? {
        guard
            let sourceDisplay = snapshot.displaysByUUID[source.displayUUID],
            let destinationDisplay = snapshot.displaysByUUID[destination.displayUUID],
            PortalGeometry.willCrossEdge(
                previousPoint: previousPoint,
                currentPoint: point,
                delta: delta,
                frame: sourceDisplay.frame,
                edge: source.edge,
                threshold: snapshot.preferences.edgeThreshold
            ),
            PortalGeometry.segmentContains(
                point: point,
                segment: source,
                frame: sourceDisplay.frame,
                tolerance: snapshot.preferences.edgeThreshold
            )
        else {
            return nil
        }

        let mapped = PortalGeometry.destinationPoint(
            sourcePoint: point,
            source: source,
            sourceFrame: sourceDisplay.frame,
            destination: destination,
            destinationFrame: destinationDisplay.frame,
            inset: snapshot.preferences.destinationInset
        )
        let overshoot = PortalGeometry.outwardOvershoot(
            previousPoint: previousPoint,
            delta: delta,
            frame: sourceDisplay.frame,
            edge: source.edge
        )
        let carried = PortalGeometry.carryingMomentum(
            from: mapped,
            overshoot: overshoot,
            transfer: snapshot.preferences.momentumTransfer,
            destinationEdge: destination.edge,
            destinationFrame: destinationDisplay.frame
        )
        let remappedDelta = PortalGeometry.remappedDelta(
            delta,
            source: source,
            sourceFrame: sourceDisplay.frame,
            destination: destination,
            destinationFrame: destinationDisplay.frame
        )
        return PortalTransition(
            point: CGPoint(x: carried.x, y: carried.y),
            delta: remappedDelta
        )
    }

    private func apply(_ transition: PortalTransition, to event: CGEvent, showIndicator: Bool) {
        lastWarpTime = ProcessInfo.processInfo.systemUptime
        CGWarpMouseCursorPosition(transition.point)
        event.location = transition.point
        event.setDoubleValueField(.mouseEventDeltaX, value: transition.delta.x)
        event.setDoubleValueField(.mouseEventDeltaY, value: transition.delta.y)
        lastPointerLocation = PointerVector(x: transition.point.x, y: transition.point.y)
        if showIndicator {
            onArrival(transition.point)
        }
    }

    private func isSuspended(flags: CGEventFlags, modifier: SuspendModifier) -> Bool {
        switch modifier {
        case .option: flags.contains(.maskAlternate)
        case .control: flags.contains(.maskControl)
        case .command: flags.contains(.maskCommand)
        case .shift: flags.contains(.maskShift)
        case .none: false
        }
    }
}
