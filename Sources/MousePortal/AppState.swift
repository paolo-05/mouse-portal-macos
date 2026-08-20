import AppKit
import Combine
import MousePortalCore
import ServiceManagement

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var displays: [DisplayDescriptor]
    @Published private(set) var configuration: AppConfiguration
    @Published private(set) var activeProfileID: String
    @Published private(set) var engineState: PortalEngine.State = .stopped
    @Published var errorMessage: String?

    lazy var engine: PortalEngine = {
        let engine = PortalEngine { [weak self] in
            self?.engineSnapshot() ?? EngineSnapshot(
                displaysByUUID: [:],
                portals: [],
                preferences: PortalPreferences()
            )
        }
        engine.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.engineState = state
            }
        }
        return engine
    }()

    init() {
        let detectedDisplays = DisplayService.activeDisplays()
        var loadedConfiguration = ConfigurationStore.load()
        let signature = Self.profileID(for: detectedDisplays)

        if !signature.isEmpty && !loadedConfiguration.profiles.contains(where: { $0.id == signature }) {
            loadedConfiguration.profiles.append(
                DisplayProfile(displayUUIDs: detectedDisplays.map(\.uuid))
            )
        }

        displays = detectedDisplays
        configuration = loadedConfiguration
        activeProfileID = signature
        synchronizeLaunchAtLoginPreference()
        persist()
    }

    var currentProfile: DisplayProfile? {
        configuration.profiles.first(where: { $0.id == activeProfileID })
    }

    var activePortals: [Portal] {
        currentProfile?.portals ?? []
    }

    var accessibilityGranted: Bool {
        PortalEngine.hasAccessibilityPermission()
    }

    var displayStatusLabel: String {
        switch displays.count {
        case 0: "No displays detected"
        case 1: "1 display detected"
        default: "\(displays.count) displays detected"
        }
    }

    func start() {
        engine.start()
    }

    func refreshDisplays() {
        displays = DisplayService.activeDisplays()
        let signature = Self.profileID(for: displays)
        activeProfileID = signature

        guard !signature.isEmpty else { return }
        if !configuration.profiles.contains(where: { $0.id == signature }) {
            configuration.profiles.append(DisplayProfile(displayUUIDs: displays.map(\.uuid)))
            persist()
        }
        objectWillChange.send()
    }

    func setGlobalEnabled(_ enabled: Bool) {
        configuration.preferences.isGloballyEnabled = enabled
        persist()
    }

    func toggleGlobalEnabled() {
        setGlobalEnabled(!configuration.preferences.isGloballyEnabled)
    }

    func emergencyDisable() {
        setGlobalEnabled(false)
    }

    func addPortal(source: EdgeSegment, destination: EdgeSegment) {
        guard source.displayUUID != destination.displayUUID else { return }
        let usedNames = Set(activePortals.map(\.name))
        var ordinal = activePortals.count + 1
        while usedNames.contains("Portal \(ordinal)") { ordinal += 1 }

        let color = PortalColor.allCases[activePortals.count % PortalColor.allCases.count]
        let portal = Portal(
            name: "Portal \(ordinal)",
            color: color,
            source: source,
            destination: destination
        )
        mutateCurrentProfile { profile in
            profile.portals.append(portal)
        }
    }

    func updatePortal(_ portal: Portal) {
        mutateCurrentProfile { profile in
            guard let index = profile.portals.firstIndex(where: { $0.id == portal.id }) else { return }
            profile.portals[index] = portal
        }
    }

    func setPortalEnabled(_ id: UUID, enabled: Bool) {
        mutateCurrentProfile { profile in
            guard let index = profile.portals.firstIndex(where: { $0.id == id }) else { return }
            profile.portals[index].isEnabled = enabled
        }
    }

    func deletePortal(_ id: UUID) {
        mutateCurrentProfile { profile in
            profile.portals.removeAll(where: { $0.id == id })
        }
    }

    func updatePreferences(_ transform: (inout PortalPreferences) -> Void) {
        transform(&configuration.preferences)
        persist()
    }

    func resetPreferencesToDefaults() {
        var defaults = PortalPreferences()

        if SMAppService.mainApp.status == .enabled {
            do {
                try SMAppService.mainApp.unregister()
            } catch {
                defaults.launchAtLogin = true
                errorMessage = "Launch at Login could not be reset: \(error.localizedDescription)"
            }
        }

        configuration.preferences = defaults
        persist()
    }

    func requestAccessibilityPermission() {
        engine.start(promptForPermission: true)
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            configuration.preferences.launchAtLogin = enabled
            persist()
        } catch {
            errorMessage = "Launch at Login could not be changed: \(error.localizedDescription)"
            synchronizeLaunchAtLoginPreference()
        }
    }

    func exportConfiguration(to url: URL) {
        do {
            try ConfigurationStore.export(configuration, to: url)
        } catch {
            errorMessage = "The configuration could not be exported: \(error.localizedDescription)"
        }
    }

    func importConfiguration(from url: URL) {
        do {
            configuration = try ConfigurationStore.importConfiguration(from: url)
            refreshDisplays()
            persist()
        } catch {
            errorMessage = "The configuration could not be imported: \(error.localizedDescription)"
        }
    }

    func diagnosticsText() -> String {
        let permission = accessibilityGranted ? "Granted" : "Not granted"
        let displayLines = displays.map { display in
            let frame = display.frame
            return "\(display.name)\n  UUID: \(display.uuid)\n  ID: \(display.displayID)\n  Frame: \(Int(frame.x)), \(Int(frame.y)), \(Int(frame.width)) × \(Int(frame.height))\n  Rotation: \(Int(display.rotation))°"
        }
        return ([
            "MousePortal diagnostics",
            "Accessibility: \(permission)",
            "Engine: \(engineState.label)",
            "Active profile: \(activeProfileID.isEmpty ? "None" : activeProfileID)",
            ""
        ] + displayLines).joined(separator: "\n")
    }

    private func mutateCurrentProfile(_ transform: (inout DisplayProfile) -> Void) {
        guard let index = configuration.profiles.firstIndex(where: { $0.id == activeProfileID }) else {
            return
        }
        transform(&configuration.profiles[index])
        configuration.profiles[index].updatedAt = Date()
        persist()
    }

    private func engineSnapshot() -> EngineSnapshot {
        EngineSnapshot(
            displaysByUUID: Dictionary(uniqueKeysWithValues: displays.map { ($0.uuid, $0) }),
            portals: activePortals,
            preferences: configuration.preferences
        )
    }

    private func persist() {
        ConfigurationStore.save(configuration)
        objectWillChange.send()
    }

    private func synchronizeLaunchAtLoginPreference() {
        configuration.preferences.launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private static func profileID(for displays: [DisplayDescriptor]) -> String {
        displays.map(\.uuid).sorted().joined(separator: "|")
    }
}
