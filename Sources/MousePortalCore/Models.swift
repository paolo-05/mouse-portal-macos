import Foundation

public struct PortalRect: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var minX: Double { x }
    public var maxX: Double { x + width }
    public var minY: Double { y }
    public var maxY: Double { y + height }
}

public struct DisplayDescriptor: Identifiable, Codable, Hashable, Sendable {
    public var id: String { uuid }
    public var uuid: String
    public var displayID: UInt32
    public var name: String
    public var frame: PortalRect
    public var rotation: Double
    public var isMain: Bool

    public init(
        uuid: String,
        displayID: UInt32,
        name: String,
        frame: PortalRect,
        rotation: Double,
        isMain: Bool
    ) {
        self.uuid = uuid
        self.displayID = displayID
        self.name = name
        self.frame = frame
        self.rotation = rotation
        self.isMain = isMain
    }
}

public enum DisplayEdge: String, Codable, CaseIterable, Hashable, Sendable {
    case top
    case right
    case bottom
    case left

    public var label: String { rawValue.capitalized }
}

public struct EdgeSegment: Codable, Hashable, Sendable {
    public var displayUUID: String
    public var edge: DisplayEdge
    public var start: Double
    public var end: Double

    public init(displayUUID: String, edge: DisplayEdge, start: Double, end: Double) {
        self.displayUUID = displayUUID
        self.edge = edge
        self.start = min(start, end).clamped(to: 0...1)
        self.end = max(start, end).clamped(to: 0...1)
    }

    public var midpoint: Double { (start + end) / 2 }

    private enum CodingKeys: String, CodingKey {
        case displayUUID, edge, start, end
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            displayUUID: try container.decode(String.self, forKey: .displayUUID),
            edge: try container.decode(DisplayEdge.self, forKey: .edge),
            start: try container.decode(Double.self, forKey: .start),
            end: try container.decode(Double.self, forKey: .end)
        )
    }
}

public enum PortalDirection: String, Codable, CaseIterable, Hashable, Sendable {
    case bidirectional
    case sourceToDestination

    public var label: String {
        switch self {
        case .bidirectional: "Bidirectional"
        case .sourceToDestination: "One way"
        }
    }
}

public enum PortalColor: String, Codable, CaseIterable, Hashable, Sendable {
    case blue
    case purple
    case orange
    case green
    case pink
    case teal

    public var label: String { rawValue.capitalized }
}

public struct Portal: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var color: PortalColor
    public var source: EdgeSegment
    public var destination: EdgeSegment
    public var direction: PortalDirection
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        color: PortalColor,
        source: EdgeSegment,
        destination: EdgeSegment,
        direction: PortalDirection = .bidirectional,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.source = source
        self.destination = destination
        self.direction = direction
        self.isEnabled = isEnabled
    }
}

public struct DisplayProfile: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var displayUUIDs: [String]
    public var portals: [Portal]
    public var updatedAt: Date

    public init(displayUUIDs: [String], portals: [Portal] = [], updatedAt: Date = Date()) {
        let normalized = displayUUIDs.sorted()
        self.id = normalized.joined(separator: "|")
        self.displayUUIDs = normalized
        self.portals = portals
        self.updatedAt = updatedAt
    }
}

public enum SuspendModifier: String, Codable, CaseIterable, Hashable, Sendable {
    case option
    case control
    case command
    case shift
    case none

    public var label: String {
        switch self {
        case .option: "Option"
        case .control: "Control"
        case .command: "Command"
        case .shift: "Shift"
        case .none: "None"
        }
    }
}

public enum ShortcutModifier: String, Codable, CaseIterable, Hashable, Sendable {
    case control
    case option
    case command
    case shift

    public var label: String {
        switch self {
        case .control: "Control"
        case .option: "Option"
        case .command: "Command"
        case .shift: "Shift"
        }
    }

    public var symbol: String {
        switch self {
        case .control: "⌃"
        case .option: "⌥"
        case .command: "⌘"
        case .shift: "⇧"
        }
    }
}

public struct ShortcutConfiguration: Codable, Hashable, Sendable {
    public var key: String
    public var modifiers: [ShortcutModifier]

    public init(
        key: String = "p",
        modifiers: [ShortcutModifier] = [.control, .option, .command]
    ) {
        self.key = String(key.lowercased().prefix(1))
        self.modifiers = modifiers
    }

    public var displayLabel: String {
        let ordered = ShortcutModifier.allCases.filter(modifiers.contains)
        return ordered.map(\.symbol).joined() + key.uppercased()
    }

    private enum CodingKeys: String, CodingKey {
        case key, modifiers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedKey = try container.decodeIfPresent(String.self, forKey: .key) ?? "p"
        let decodedModifiers = try container.decodeIfPresent([ShortcutModifier].self, forKey: .modifiers)
            ?? [.control, .option, .command]
        self.init(
            key: decodedKey.isEmpty ? "p" : decodedKey,
            modifiers: decodedModifiers.isEmpty ? [.control, .option, .command] : decodedModifiers
        )
    }
}

public struct PortalPreferences: Codable, Hashable, Sendable {
    public var isGloballyEnabled = true
    public var destinationInset = 6.0
    public var edgeThreshold = 3.0
    public var cooldownSeconds = 0.14
    public var minimumVelocity = 0.0
    public var momentumTransfer = 1.0
    public var suspendModifier: SuspendModifier = .option
    public var toggleShortcut = ShortcutConfiguration()
    public var showsArrivalIndicator = false
    public var launchAtLogin = false

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case isGloballyEnabled
        case destinationInset
        case edgeThreshold
        case cooldownSeconds
        case minimumVelocity
        case momentumTransfer
        case suspendModifier
        case toggleShortcut
        case showsArrivalIndicator
        case launchAtLogin
    }

    public init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isGloballyEnabled = try container.decodeIfPresent(Bool.self, forKey: .isGloballyEnabled) ?? isGloballyEnabled
        destinationInset = (try container.decodeIfPresent(Double.self, forKey: .destinationInset) ?? destinationInset).clamped(to: 1...64)
        edgeThreshold = (try container.decodeIfPresent(Double.self, forKey: .edgeThreshold) ?? edgeThreshold).clamped(to: 1...20)
        cooldownSeconds = (try container.decodeIfPresent(Double.self, forKey: .cooldownSeconds) ?? cooldownSeconds).clamped(to: 0.03...2)
        minimumVelocity = (try container.decodeIfPresent(Double.self, forKey: .minimumVelocity) ?? minimumVelocity).clamped(to: 0...10_000)
        momentumTransfer = (try container.decodeIfPresent(Double.self, forKey: .momentumTransfer) ?? momentumTransfer).clamped(to: 0...1.5)
        suspendModifier = try container.decodeIfPresent(SuspendModifier.self, forKey: .suspendModifier) ?? suspendModifier
        toggleShortcut = try container.decodeIfPresent(ShortcutConfiguration.self, forKey: .toggleShortcut) ?? toggleShortcut
        showsArrivalIndicator = try container.decodeIfPresent(Bool.self, forKey: .showsArrivalIndicator) ?? showsArrivalIndicator
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? launchAtLogin
    }
}

public struct AppConfiguration: Codable, Hashable, Sendable {
    public var schemaVersion = 1
    public var preferences = PortalPreferences()
    public var profiles: [DisplayProfile] = []

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, preferences, profiles
    }

    public init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? schemaVersion
        preferences = try container.decodeIfPresent(PortalPreferences.self, forKey: .preferences) ?? preferences
        profiles = try container.decodeIfPresent([DisplayProfile].self, forKey: .profiles) ?? profiles
    }
}

public extension BinaryFloatingPoint {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
