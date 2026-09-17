import MousePortalCore
import SwiftUI

private struct EdgeHit {
    var display: DisplayDescriptor
    var edge: DisplayEdge
    var fraction: Double
}

private enum SegmentSide {
    case source
    case destination
}

private enum SegmentBound {
    case start
    case end
}

private enum CanvasDragMode {
    case creating(EdgeHit)
    case resizing(portal: Portal, side: SegmentSide, bound: SegmentBound)
}

private struct CanvasTransform {
    let displays: [DisplayDescriptor]
    let scale: Double
    let offset: CGPoint
    let origin: CGPoint

    init(displays: [DisplayDescriptor], size: CGSize) {
        self.displays = displays
        guard !displays.isEmpty else {
            scale = 1
            offset = .zero
            origin = .zero
            return
        }

        let minX = displays.map(\.frame.minX).min() ?? 0
        let minY = displays.map(\.frame.minY).min() ?? 0
        let maxX = displays.map(\.frame.maxX).max() ?? 1
        let maxY = displays.map(\.frame.maxY).max() ?? 1
        let width = max(maxX - minX, 1)
        let height = max(maxY - minY, 1)
        let availableWidth = max(size.width - 96, 1)
        let availableHeight = max(size.height - 96, 1)
        let fittedScale = min(availableWidth / width, availableHeight / height)

        scale = fittedScale
        origin = CGPoint(x: minX, y: minY)
        offset = CGPoint(
            x: (size.width - width * fittedScale) / 2,
            y: (size.height - height * fittedScale) / 2
        )
    }

    func rect(for display: DisplayDescriptor) -> CGRect {
        CGRect(
            x: offset.x + (display.frame.x - origin.x) * scale,
            y: offset.y + (display.frame.y - origin.y) * scale,
            width: display.frame.width * scale,
            height: display.frame.height * scale
        )
    }

    func point(for segment: EdgeSegment, fraction: Double) -> CGPoint? {
        guard let display = displays.first(where: { $0.uuid == segment.displayUUID }) else { return nil }
        return point(on: display, edge: segment.edge, fraction: fraction)
    }

    func point(on display: DisplayDescriptor, edge: DisplayEdge, fraction: Double) -> CGPoint {
        let rect = rect(for: display)
        return switch edge {
        case .left: CGPoint(x: rect.minX, y: rect.minY + rect.height * fraction)
        case .right: CGPoint(x: rect.maxX, y: rect.minY + rect.height * fraction)
        case .top: CGPoint(x: rect.minX + rect.width * fraction, y: rect.minY)
        case .bottom: CGPoint(x: rect.minX + rect.width * fraction, y: rect.maxY)
        }
    }

    func fraction(at point: CGPoint, display: DisplayDescriptor, edge: DisplayEdge) -> Double {
        let rect = rect(for: display)
        return switch edge {
        case .left, .right: Double((point.y - rect.minY) / max(rect.height, 1)).clamped(to: 0...1)
        case .top, .bottom: Double((point.x - rect.minX) / max(rect.width, 1)).clamped(to: 0...1)
        }
    }

    func edgeHit(at point: CGPoint, tolerance: Double = 14) -> EdgeHit? {
        var candidates: [(Double, EdgeHit)] = []
        for display in displays {
            let rect = rect(for: display).insetBy(dx: -tolerance, dy: -tolerance)
            guard rect.contains(point) else { continue }
            let visibleRect = self.rect(for: display)
            let distances: [(DisplayEdge, Double)] = [
                (.left, abs(point.x - visibleRect.minX)),
                (.right, abs(point.x - visibleRect.maxX)),
                (.top, abs(point.y - visibleRect.minY)),
                (.bottom, abs(point.y - visibleRect.maxY))
            ]
            if let nearest = distances.min(by: { $0.1 < $1.1 }), nearest.1 <= tolerance {
                candidates.append((
                    nearest.1,
                    EdgeHit(
                        display: display,
                        edge: nearest.0,
                        fraction: fraction(at: point, display: display, edge: nearest.0)
                    )
                ))
            }
        }
        return candidates.min(by: { $0.0 < $1.0 })?.1
    }
}

struct PortalCanvasView: View {
    var displays: [DisplayDescriptor]
    var portals: [Portal]
    @Binding var selectedPortalID: UUID?
    var onCreate: (EdgeSegment, EdgeSegment) -> Void
    var onUpdate: (Portal) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragMode: CanvasDragMode?
    @State private var dragPoint: CGPoint?

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                let transform = CanvasTransform(displays: displays, size: proxy.size)
                TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || portals.isEmpty)) { timeline in
                    Canvas { context, _ in
                        drawDisplays(context: &context, transform: transform)
                        drawPortals(
                            context: &context,
                            transform: transform,
                            timeline: timeline.date.timeIntervalSinceReferenceDate
                        )
                        drawDragPreview(context: &context, transform: transform)
                    }
                }
                .contentShape(Rectangle())
                .gesture(dragGesture(transform: transform))
                .accessibilityLabel("Display portal editor")
                .accessibilityHint("Drag from one display edge to another to create a portal")
            }

            if displays.count < 2 {
                guidanceBar(
                    icon: "display.2",
                    title: "Connect another display",
                    message: "MousePortal needs at least two active displays to create a portal."
                )
            } else if portals.isEmpty {
                guidanceBar(
                    icon: "cursorarrow.motionlines",
                    title: "Drag between display edges",
                    message: "Start on one display edge, then release on another display."
                )
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func guidanceBar(icon: String, title: String, message: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) {
            Divider()
        }
        .accessibilityElement(children: .combine)
    }

    private func drawDisplays(context: inout GraphicsContext, transform: CanvasTransform) {
        for display in displays {
            let rect = transform.rect(for: display)
            let shape = Path(roundedRect: rect, cornerRadius: 9)
            context.fill(shape, with: .color(Color(nsColor: .windowBackgroundColor)))
            context.stroke(
                shape,
                with: .color(display.isMain ? Color.accentColor.opacity(0.72) : Color.secondary.opacity(0.5)),
                lineWidth: display.isMain ? 2 : 1
            )

            let label = context.resolve(
                Text(display.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.primary)
            )
            context.draw(label, at: CGPoint(x: rect.midX, y: rect.midY - 7))
            let resolution = context.resolve(
                Text("\(Int(display.frame.width)) × \(Int(display.frame.height))")
                    .font(.system(size: 10))
                    .foregroundColor(Color.secondary)
            )
            context.draw(resolution, at: CGPoint(x: rect.midX, y: rect.midY + 11))
        }
    }

    private func drawPortals(
        context: inout GraphicsContext,
        transform: CanvasTransform,
        timeline: TimeInterval
    ) {
        for portal in portals {
            guard
                let sourceStart = transform.point(for: portal.source, fraction: portal.source.start),
                let sourceEnd = transform.point(for: portal.source, fraction: portal.source.end),
                let destinationStart = transform.point(for: portal.destination, fraction: portal.destination.start),
                let destinationEnd = transform.point(for: portal.destination, fraction: portal.destination.end)
            else { continue }

            let color = portal.color.swiftUIColor.opacity(portal.isEnabled ? 1 : 0.38)
            var sourcePath = Path()
            sourcePath.move(to: sourceStart)
            sourcePath.addLine(to: sourceEnd)
            context.stroke(sourcePath, with: .color(color), style: StrokeStyle(lineWidth: 7, lineCap: .round))

            var destinationPath = Path()
            destinationPath.move(to: destinationStart)
            destinationPath.addLine(to: destinationEnd)
            context.stroke(destinationPath, with: .color(color), style: StrokeStyle(lineWidth: 7, lineCap: .round))

            let sourceMid = midpoint(sourceStart, sourceEnd)
            let destinationMid = midpoint(destinationStart, destinationEnd)
            let curve = connectorPath(from: sourceMid, to: destinationMid)
            context.stroke(
                curve,
                with: .color(color.opacity(selectedPortalID == portal.id ? 0.72 : 0.34)),
                style: StrokeStyle(lineWidth: selectedPortalID == portal.id ? 2.2 : 1.2, dash: [5, 5])
            )

            if portal.isEnabled {
                let progress = reduceMotion ? 0.5 : timeline.truncatingRemainder(dividingBy: 1.25) / 1.25
                let animatedPoint = quadraticPoint(from: sourceMid, to: destinationMid, progress: progress)
                context.fill(
                    Path(ellipseIn: CGRect(x: animatedPoint.x - 4, y: animatedPoint.y - 4, width: 8, height: 8)),
                    with: .color(color)
                )
            }

            if selectedPortalID == portal.id {
                for handle in [sourceStart, sourceEnd, destinationStart, destinationEnd] {
                    context.fill(
                        Path(ellipseIn: CGRect(x: handle.x - 5, y: handle.y - 5, width: 10, height: 10)),
                        with: .color(Color(nsColor: .windowBackgroundColor))
                    )
                    context.stroke(
                        Path(ellipseIn: CGRect(x: handle.x - 5, y: handle.y - 5, width: 10, height: 10)),
                        with: .color(color),
                        lineWidth: 2
                    )
                }
            }
        }
    }

    private func drawDragPreview(context: inout GraphicsContext, transform: CanvasTransform) {
        guard case .creating(let source) = dragMode, let dragPoint else { return }
        let start = transform.point(on: source.display, edge: source.edge, fraction: source.fraction)
        context.stroke(
            connectorPath(from: start, to: dragPoint),
            with: .color(Color.accentColor.opacity(0.8)),
            style: StrokeStyle(lineWidth: 2, dash: [6, 4])
        )
        context.fill(
            Path(ellipseIn: CGRect(x: start.x - 5, y: start.y - 5, width: 10, height: 10)),
            with: .color(Color.accentColor)
        )
    }

    private func dragGesture(transform: CanvasTransform) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                dragPoint = value.location
                if dragMode == nil {
                    if let handle = resizeHandle(at: value.startLocation, transform: transform) {
                        selectedPortalID = handle.portal.id
                        dragMode = .resizing(portal: handle.portal, side: handle.side, bound: handle.bound)
                    } else if let source = transform.edgeHit(at: value.startLocation) {
                        dragMode = .creating(source)
                    }
                }

                if case .resizing(let original, let side, let bound) = dragMode {
                    resize(original, side: side, bound: bound, at: value.location, transform: transform)
                }
            }
            .onEnded { value in
                defer {
                    dragMode = nil
                    dragPoint = nil
                }

                guard case .creating(let source) = dragMode,
                      let destination = transform.edgeHit(at: value.location),
                      source.display.uuid != destination.display.uuid
                else { return }

                let sourceRange = segmentRange(around: source.fraction)
                let destinationRange = segmentRange(around: destination.fraction)
                onCreate(
                    EdgeSegment(
                        displayUUID: source.display.uuid,
                        edge: source.edge,
                        start: sourceRange.lowerBound,
                        end: sourceRange.upperBound
                    ),
                    EdgeSegment(
                        displayUUID: destination.display.uuid,
                        edge: destination.edge,
                        start: destinationRange.lowerBound,
                        end: destinationRange.upperBound
                    )
                )
            }
    }

    private func resizeHandle(
        at point: CGPoint,
        transform: CanvasTransform
    ) -> (portal: Portal, side: SegmentSide, bound: SegmentBound)? {
        for portal in portals where portal.id == selectedPortalID {
            let handles: [(CGPoint?, SegmentSide, SegmentBound)] = [
                (transform.point(for: portal.source, fraction: portal.source.start), .source, .start),
                (transform.point(for: portal.source, fraction: portal.source.end), .source, .end),
                (transform.point(for: portal.destination, fraction: portal.destination.start), .destination, .start),
                (transform.point(for: portal.destination, fraction: portal.destination.end), .destination, .end)
            ]
            for (handlePoint, side, bound) in handles {
                guard let handlePoint else { continue }
                if hypot(point.x - handlePoint.x, point.y - handlePoint.y) <= 11 {
                    return (portal, side, bound)
                }
            }
        }
        return nil
    }

    private func resize(
        _ original: Portal,
        side: SegmentSide,
        bound: SegmentBound,
        at point: CGPoint,
        transform: CanvasTransform
    ) {
        var portal = original
        var segment = side == .source ? portal.source : portal.destination
        guard let display = displays.first(where: { $0.uuid == segment.displayUUID }) else { return }
        let fraction = transform.fraction(at: point, display: display, edge: segment.edge)
        let minimumLength = 0.03

        switch bound {
        case .start: segment.start = min(fraction, segment.end - minimumLength).clamped(to: 0...1)
        case .end: segment.end = max(fraction, segment.start + minimumLength).clamped(to: 0...1)
        }

        if side == .source { portal.source = segment } else { portal.destination = segment }
        onUpdate(portal)
    }

    private func segmentRange(around center: Double) -> ClosedRange<Double> {
        let halfLength = 0.11
        let start = max(0, min(center - halfLength, 1 - halfLength * 2))
        return start...(start + halfLength * 2)
    }

    private func midpoint(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
        CGPoint(x: (lhs.x + rhs.x) / 2, y: (lhs.y + rhs.y) / 2)
    }

    private func connectorPath(from start: CGPoint, to end: CGPoint) -> Path {
        var path = Path()
        path.move(to: start)
        let control = CGPoint(x: (start.x + end.x) / 2, y: min(start.y, end.y) - abs(end.x - start.x) * 0.08)
        path.addQuadCurve(to: end, control: control)
        return path
    }

    private func quadraticPoint(from start: CGPoint, to end: CGPoint, progress: Double) -> CGPoint {
        let control = CGPoint(x: (start.x + end.x) / 2, y: min(start.y, end.y) - abs(end.x - start.x) * 0.08)
        let inverse = 1 - progress
        return CGPoint(
            x: inverse * inverse * start.x + 2 * inverse * progress * control.x + progress * progress * end.x,
            y: inverse * inverse * start.y + 2 * inverse * progress * control.y + progress * progress * end.y
        )
    }
}
