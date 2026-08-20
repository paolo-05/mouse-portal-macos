import AppKit
import CoreGraphics
import MousePortalCore

enum DisplayService {
    static func activeDisplays() -> [DisplayDescriptor] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else {
            return []
        }

        var identifiers = Array(repeating: CGDirectDisplayID(), count: Int(count))
        guard CGGetActiveDisplayList(count, &identifiers, &count) == .success else {
            return []
        }

        let screenNames: [CGDirectDisplayID: String] = Dictionary(
            uniqueKeysWithValues: NSScreen.screens.compactMap { screen in
                guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                    return nil
                }
                return (CGDirectDisplayID(number.uint32Value), screen.localizedName)
            }
        )

        return identifiers.prefix(Int(count)).map { displayID in
            let bounds = CGDisplayBounds(displayID)
            let displayUUID: String
            if let uuid = CGDisplayCreateUUIDFromDisplayID(displayID) {
                displayUUID = CFUUIDCreateString(nil, uuid.takeRetainedValue()) as String
            } else {
                displayUUID = "display-\(displayID)"
            }

            return DisplayDescriptor(
                uuid: displayUUID,
                displayID: displayID,
                name: screenNames[displayID] ?? "Display \(displayID)",
                frame: PortalRect(
                    x: bounds.origin.x,
                    y: bounds.origin.y,
                    width: bounds.width,
                    height: bounds.height
                ),
                rotation: CGDisplayRotation(displayID),
                isMain: CGDisplayIsMain(displayID) != 0
            )
        }
        .sorted { lhs, rhs in
            if lhs.isMain != rhs.isMain { return lhs.isMain }
            if lhs.frame.x != rhs.frame.x { return lhs.frame.x < rhs.frame.x }
            return lhs.frame.y < rhs.frame.y
        }
    }
}
