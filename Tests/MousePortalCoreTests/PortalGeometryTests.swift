import Testing
import MousePortalCore

@Suite
struct PortalGeometryTests {
    private let sourceFrame = PortalRect(x: 0, y: 0, width: 1440, height: 900)
    private let destinationFrame = PortalRect(x: 1800, y: -200, width: 1080, height: 1920)

    @Test
    func mapsVerticalSegmentsProportionally() {
        let source = EdgeSegment(displayUUID: "source", edge: .right, start: 0.2, end: 0.8)
        let destination = EdgeSegment(displayUUID: "destination", edge: .left, start: 0.6, end: 0.9)

        let point = PortalGeometry.destinationPoint(
            sourcePoint: PointerVector(x: 1440, y: 450),
            source: source,
            sourceFrame: sourceFrame,
            destination: destination,
            destinationFrame: destinationFrame,
            inset: 6
        )

        #expect(abs(point.x - 1806) < 0.001)
        #expect(abs(point.y - 1240) < 0.001)
    }

    @Test
    func mapsBetweenPerpendicularEdges() {
        let source = EdgeSegment(displayUUID: "source", edge: .right, start: 0, end: 1)
        let destination = EdgeSegment(displayUUID: "destination", edge: .top, start: 0.25, end: 0.75)

        let point = PortalGeometry.destinationPoint(
            sourcePoint: PointerVector(x: 1440, y: 225),
            source: source,
            sourceFrame: sourceFrame,
            destination: destination,
            destinationFrame: destinationFrame,
            inset: 8
        )

        #expect(abs(point.x - 2205) < 0.001)
        #expect(abs(point.y - -192) < 0.001)
    }

    @Test
    func detectsOutwardMovementForEveryEdge() {
        #expect(PortalGeometry.isOutwardMovement(PointerVector(x: -1, y: 0), at: .left))
        #expect(PortalGeometry.isOutwardMovement(PointerVector(x: 1, y: 0), at: .right))
        #expect(PortalGeometry.isOutwardMovement(PointerVector(x: 0, y: -1), at: .top))
        #expect(PortalGeometry.isOutwardMovement(PointerVector(x: 0, y: 1), at: .bottom))
        #expect(!PortalGeometry.isOutwardMovement(PointerVector(x: -1, y: 0), at: .right))
    }

    @Test
    func edgeThresholdIncludesSlightlyInsetPointer() {
        #expect(
            PortalGeometry.isNearEdge(
                point: PointerVector(x: 1438, y: 500),
                frame: sourceFrame,
                edge: .right,
                threshold: 3
            )
        )
        #expect(
            !PortalGeometry.isNearEdge(
                point: PointerVector(x: 1435, y: 500),
                frame: sourceFrame,
                edge: .right,
                threshold: 3
            )
        )
    }

    @Test
    func portalWaitsUntilTheMovementWouldActuallyCrossTheEdge() {
        #expect(
            !PortalGeometry.willCrossEdge(
                previousPoint: PointerVector(x: 1434, y: 500),
                currentPoint: PointerVector(x: 1437, y: 500),
                delta: PointerVector(x: 3, y: 0),
                frame: sourceFrame,
                edge: .right,
                threshold: 3
            )
        )
        #expect(
            PortalGeometry.willCrossEdge(
                previousPoint: PointerVector(x: 1437, y: 500),
                currentPoint: PointerVector(x: 1439, y: 500),
                delta: PointerVector(x: 5, y: 0),
                frame: sourceFrame,
                edge: .right,
                threshold: 3
            )
        )
    }

    @Test
    func portalStillOpensWhenThePointerIsClampedAtTheBoundary() {
        #expect(
            PortalGeometry.willCrossEdge(
                previousPoint: PointerVector(x: 1439, y: 500),
                currentPoint: PointerVector(x: 1439, y: 500),
                delta: PointerVector(x: 1, y: 0),
                frame: sourceFrame,
                edge: .right,
                threshold: 3
            )
        )
    }

    @Test
    func segmentNormalizesItsRange() {
        let segment = EdgeSegment(displayUUID: "display", edge: .left, start: 1.4, end: -0.2)
        #expect(segment.start == 0)
        #expect(segment.end == 1)
    }

    @Test
    func carriesOnlyMovementThatWouldHaveCrossedTheEdge() {
        let overshoot = PortalGeometry.outwardOvershoot(
            previousPoint: PointerVector(x: 1436, y: 450),
            delta: PointerVector(x: 9, y: 0),
            frame: sourceFrame,
            edge: .right
        )
        #expect(abs(overshoot - 5) < 0.001)
    }

    @Test
    func appliesOvershootInsideTheDestinationEdge() {
        let carried = PortalGeometry.carryingMomentum(
            from: PointerVector(x: 1806, y: 600),
            overshoot: 8,
            transfer: 1,
            destinationEdge: .left,
            destinationFrame: destinationFrame
        )
        #expect(abs(carried.x - 1814) < 0.001)
        #expect(abs(carried.y - 600) < 0.001)
    }

    @Test
    func remapsVelocityIntoTheDestinationEdge() {
        let source = EdgeSegment(displayUUID: "source", edge: .right, start: 0, end: 1)
        let destination = EdgeSegment(displayUUID: "destination", edge: .top, start: 0, end: 1)
        let remapped = PortalGeometry.remappedDelta(
            PointerVector(x: 12, y: 3),
            source: source,
            sourceFrame: sourceFrame,
            destination: destination,
            destinationFrame: destinationFrame
        )
        #expect(abs(remapped.x - 3.6) < 0.001)
        #expect(abs(remapped.y - 12) < 0.001)
    }
}
