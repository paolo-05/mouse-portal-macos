import AppKit
import Combine
import MousePortalCore

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let state: AppState
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var cancellables: Set<AnyCancellable> = []

    var onOpenEditor: () -> Void = {}

    init(state: AppState) {
        self.state = state
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "arrow.left.arrow.right.circle", accessibilityDescription: "MousePortal")
            button.image?.isTemplate = true
            button.toolTip = "MousePortal"
        }
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu

        state.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusIcon()
            }
            .store(in: &cancellables)
        updateStatusIcon()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let enabled = state.configuration.preferences.isGloballyEnabled
        let toggle = menuItem(
            enabled ? "Disable MousePortal" : "Enable MousePortal",
            action: #selector(toggleGlobal)
        )
        let shortcut = state.configuration.preferences.toggleShortcut
        toggle.keyEquivalent = shortcut.key
        toggle.keyEquivalentModifierMask = NSEvent.ModifierFlags(shortcut.modifiers)
        menu.addItem(toggle)

        let status = NSMenuItem(title: state.engineState.label, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        menu.addItem(menuItem("Open Portal Editor…", action: #selector(openEditor), keyEquivalent: ","))

        if !state.activePortals.isEmpty {
            let portalsItem = NSMenuItem(title: "Portals", action: nil, keyEquivalent: "")
            let portalsMenu = NSMenu()
            for portal in state.activePortals {
                let item = menuItem(portal.name, action: #selector(togglePortal(_:)))
                item.state = portal.isEnabled ? .on : .off
                item.representedObject = portal.id.uuidString
                portalsMenu.addItem(item)
            }
            portalsItem.submenu = portalsMenu
            menu.addItem(portalsItem)
        }

        menu.addItem(menuItem("Refresh Displays", action: #selector(refreshDisplays)))
        menu.addItem(menuItem("Diagnostics…", action: #selector(openEditor)))
        menu.addItem(.separator())

        let launchAtLogin = menuItem("Launch at Login", action: #selector(toggleLaunchAtLogin))
        launchAtLogin.state = state.configuration.preferences.launchAtLogin ? .on : .off
        menu.addItem(launchAtLogin)

        let exportItem = NSMenuItem(title: "Configuration", action: nil, keyEquivalent: "")
        let configurationMenu = NSMenu()
        configurationMenu.addItem(menuItem("Import…", action: #selector(importConfiguration)))
        configurationMenu.addItem(menuItem("Export…", action: #selector(exportConfiguration)))
        exportItem.submenu = configurationMenu
        menu.addItem(exportItem)

        menu.addItem(.separator())
        let emergency = menuItem("Emergency Disable", action: #selector(emergencyDisable))
        emergency.isEnabled = enabled
        menu.addItem(emergency)
        menu.addItem(menuItem("Quit MousePortal", action: #selector(quit), keyEquivalent: "q"))
    }

    private func menuItem(
        _ title: String,
        action: Selector,
        keyEquivalent: String = ""
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.isEnabled = true
        return item
    }

    private func updateStatusIcon() {
        let enabled = state.configuration.preferences.isGloballyEnabled
        statusItem.button?.appearsDisabled = !enabled
        statusItem.button?.toolTip = enabled ? "MousePortal is enabled" : "MousePortal is disabled"
    }

    @objc private func toggleGlobal() {
        state.toggleGlobalEnabled()
    }

    @objc private func openEditor() {
        onOpenEditor()
    }

    @objc private func togglePortal(_ sender: NSMenuItem) {
        guard
            let value = sender.representedObject as? String,
            let id = UUID(uuidString: value),
            let portal = state.activePortals.first(where: { $0.id == id })
        else { return }
        state.setPortalEnabled(id, enabled: !portal.isEnabled)
    }

    @objc private func refreshDisplays() {
        state.refreshDisplays()
        state.start()
    }

    @objc private func toggleLaunchAtLogin() {
        state.setLaunchAtLogin(!state.configuration.preferences.launchAtLogin)
    }

    @objc private func importConfiguration() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        state.importConfiguration(from: url)
    }

    @objc private func exportConfiguration() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "MousePortal Configuration.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        state.exportConfiguration(to: url)
    }

    @objc private func emergencyDisable() {
        state.emergencyDisable()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
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
