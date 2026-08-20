import Foundation

public struct PointerVector: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public var magnitude: Double { hypot(x, y) }
}

public enum PortalGeometry {
    public static func inwardVector(for edge: DisplayEdge) -> PointerVector {
        switch edge {
        case .left: PointerVector(x: 1, y: 0)
        case .right: PointerVector(x: -1, y: 0)
        case .top: PointerVector(x: 0, y: 1)
        case .bottom: PointerVector(x: 0, y: -1)
        }
    }

    public static func tangentVector(for edge: DisplayEdge) -> PointerVector {
        switch edge {
        case .left, .right: PointerVector(x: 0, y: 1)
        case .top, .bottom: PointerVector(x: 1, y: 0)
        }
    }

    public static func edgeFraction(
        point: PointerVector,
        frame: PortalRect,
        edge: DisplayEdge
    ) -> Double {
        switch edge {
        case .left, .right:
            return ((point.y - frame.minY) / max(frame.height, 1)).clamped(to: 0...1)
        case .top, .bottom:
            return ((point.x - frame.minX) / max(frame.width, 1)).clamped(to: 0...1)
        }
    }

    public static func isOutwardMovement(_ delta: PointerVector, at edge: DisplayEdge) -> Bool {
        switch edge {
        case .left: delta.x < 0
        case .right: delta.x > 0
        case .top: delta.y < 0
        case .bottom: delta.y > 0
        }
    }

    public static func isNearEdge(
        point: PointerVector,
        frame: PortalRect,
        edge: DisplayEdge,
        threshold: Double
    ) -> Bool {
        let insideTangentially: Bool
        switch edge {
        case .left, .right:
            insideTangentially = point.y >= frame.minY - threshold && point.y <= frame.maxY + threshold
        case .top, .bottom:
            insideTangentially = point.x >= frame.minX - threshold && point.x <= frame.maxX + threshold
        }

        guard insideTangentially else { return false }
        switch edge {
        case .left: return abs(point.x - frame.minX) <= threshold
        case .right: return abs(point.x - frame.maxX) <= threshold
        case .top: return abs(point.y - frame.minY) <= threshold
        case .bottom: return abs(point.y - frame.maxY) <= threshold
        }
    }

    public static func willCrossEdge(
        previousPoint: PointerVector?,
        currentPoint: PointerVector,
        delta: PointerVector,
        frame: PortalRect,
        edge: DisplayEdge,
        threshold: Double
    ) -> Bool {
        guard isOutwardMovement(delta, at: edge),
              isNearEdge(point: currentPoint, frame: frame, edge: edge, threshold: threshold)
        else { return false }

        // A cursor is clamped at the last addressable pixel, so repeated outward
        // events at the boundary never produce a point outside the display.
        let contactTolerance = min(max(threshold, 0.5), 1.5)
        let isAtBoundary: Bool
        switch edge {
        case .left:
            isAtBoundary = currentPoint.x <= frame.minX + contactTolerance
        case .right:
            isAtBoundary = currentPoint.x >= frame.maxX - contactTolerance
        case .top:
            isAtBoundary = currentPoint.y <= frame.minY + contactTolerance
        case .bottom:
            isAtBoundary = currentPoint.y >= frame.maxY - contactTolerance
        }

        guard let previousPoint else { return isAtBoundary }
        let tolerance = max(threshold, 8)
        guard previousPoint.x >= frame.minX - tolerance,
              previousPoint.x <= frame.maxX + tolerance,
              previousPoint.y >= frame.minY - tolerance,
              previousPoint.y <= frame.maxY + tolerance
        else { return isAtBoundary }

        // Preserve the portion of the physical movement that lies beyond the
        // edge, but do not open the portal merely because the cursor is nearby.
        let projected = PointerVector(
            x: previousPoint.x + delta.x,
            y: previousPoint.y + delta.y
        )
        let crossesBoundary: Bool
        switch edge {
        case .left:
            crossesBoundary = projected.x <= frame.minX
        case .right:
            crossesBoundary = projected.x >= frame.maxX
        case .top:
            crossesBoundary = projected.y <= frame.minY
        case .bottom:
            crossesBoundary = projected.y >= frame.maxY
        }
        return crossesBoundary || isAtBoundary
    }

    public static func destinationPoint(
        sourcePoint: PointerVector,
        source: EdgeSegment,
        sourceFrame: PortalRect,
        destination: EdgeSegment,
        destinationFrame: PortalRect,
        inset: Double
    ) -> PointerVector {
        let sourceFraction = edgeFraction(point: sourcePoint, frame: sourceFrame, edge: source.edge)
        let span = max(source.end - source.start, 0.000_001)
        let progress = ((sourceFraction - source.start) / span).clamped(to: 0...1)
        let destinationFraction = destination.start + progress * (destination.end - destination.start)

        switch destination.edge {
        case .left:
            return PointerVector(
                x: destinationFrame.minX + inset,
                y: destinationFrame.minY + destinationFraction * destinationFrame.height
            )
        case .right:
            return PointerVector(
                x: destinationFrame.maxX - inset,
                y: destinationFrame.minY + destinationFraction * destinationFrame.height
            )
        case .top:
            return PointerVector(
                x: destinationFrame.minX + destinationFraction * destinationFrame.width,
                y: destinationFrame.minY + inset
            )
        case .bottom:
            return PointerVector(
                x: destinationFrame.minX + destinationFraction * destinationFrame.width,
                y: destinationFrame.maxY - inset
            )
        }
    }

    public static func outwardOvershoot(
        previousPoint: PointerVector?,
        delta: PointerVector,
        frame: PortalRect,
        edge: DisplayEdge
    ) -> Double {
        guard let previousPoint else { return 0 }
        let tolerance = 32.0
        guard previousPoint.x >= frame.minX - tolerance,
              previousPoint.x <= frame.maxX + tolerance,
              previousPoint.y >= frame.minY - tolerance,
              previousPoint.y <= frame.maxY + tolerance
        else { return 0 }

        let distanceToEdge: Double
        let outwardMovement: Double
        switch edge {
        case .left:
            distanceToEdge = max(0, previousPoint.x - frame.minX)
            outwardMovement = max(0, -delta.x)
        case .right:
            distanceToEdge = max(0, frame.maxX - previousPoint.x)
            outwardMovement = max(0, delta.x)
        case .top:
            distanceToEdge = max(0, previousPoint.y - frame.minY)
            outwardMovement = max(0, -delta.y)
        case .bottom:
            distanceToEdge = max(0, frame.maxY - previousPoint.y)
            outwardMovement = max(0, delta.y)
        }
        return max(0, outwardMovement - distanceToEdge)
    }

    public static func carryingMomentum(
        from point: PointerVector,
        overshoot: Double,
        transfer: Double,
        destinationEdge: DisplayEdge,
        destinationFrame: PortalRect
    ) -> PointerVector {
        let inward = inwardVector(for: destinationEdge)
        let carriedDistance = min(overshoot * transfer.clamped(to: 0...1.5), 96)
        return PointerVector(
            x: (point.x + inward.x * carriedDistance).clamped(
                to: (destinationFrame.minX + 1)...(destinationFrame.maxX - 1)
            ),
            y: (point.y + inward.y * carriedDistance).clamped(
                to: (destinationFrame.minY + 1)...(destinationFrame.maxY - 1)
            )
        )
    }

    public static func remappedDelta(
        _ delta: PointerVector,
        source: EdgeSegment,
        sourceFrame: PortalRect,
        destination: EdgeSegment,
        destinationFrame: PortalRect
    ) -> PointerVector {
        let sourceInward = inwardVector(for: source.edge)
        let sourceOutward = PointerVector(x: -sourceInward.x, y: -sourceInward.y)
        let sourceTangent = tangentVector(for: source.edge)
        let destinationInward = inwardVector(for: destination.edge)
        let destinationTangent = tangentVector(for: destination.edge)

        let normal = delta.x * sourceOutward.x + delta.y * sourceOutward.y
        let tangent = delta.x * sourceTangent.x + delta.y * sourceTangent.y
        let sourceDimension = source.edge == .left || source.edge == .right
            ? sourceFrame.height
            : sourceFrame.width
        let destinationDimension = destination.edge == .left || destination.edge == .right
            ? destinationFrame.height
            : destinationFrame.width
        let sourceLength = max((source.end - source.start) * sourceDimension, 1)
        let destinationLength = max((destination.end - destination.start) * destinationDimension, 1)
        let mappedTangent = tangent * destinationLength / sourceLength

        return PointerVector(
            x: destinationInward.x * normal + destinationTangent.x * mappedTangent,
            y: destinationInward.y * normal + destinationTangent.y * mappedTangent
        )
    }

    public static func segmentContains(
        point: PointerVector,
        segment: EdgeSegment,
        frame: PortalRect,
        tolerance: Double = 0
    ) -> Bool {
        let fraction = edgeFraction(point: point, frame: frame, edge: segment.edge)
        let dimension = segment.edge == .left || segment.edge == .right ? frame.height : frame.width
        let normalizedTolerance = tolerance / max(dimension, 1)
        return fraction >= segment.start - normalizedTolerance && fraction <= segment.end + normalizedTolerance
    }
}
