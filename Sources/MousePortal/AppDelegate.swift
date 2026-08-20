import AppKit
import MousePortalCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var state: AppState!
    private var editorWindowController: EditorWindowController!
    private var statusMenuController: StatusMenuController!
    private var indicatorController: ArrivalIndicatorController!
    private var shortcutMonitor: GlobalShortcutMonitor!
    private var screenChangeWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        state = AppState()
        editorWindowController = EditorWindowController(state: state)
        indicatorController = ArrivalIndicatorController()
        statusMenuController = StatusMenuController(state: state)
        statusMenuController.onOpenEditor = { [weak self] in
            self?.editorWindowController.show()
        }

        state.engine.onArrival = { [weak self] point in
            DispatchQueue.main.async {
                self?.indicatorController.show(at: point)
            }
        }
        state.start()

        shortcutMonitor = GlobalShortcutMonitor()
        shortcutMonitor.shortcutProvider = { [weak self] in
            self?.state.configuration.preferences.toggleShortcut ?? ShortcutConfiguration()
        }
        shortcutMonitor.onToggle = { [weak self] in
            DispatchQueue.main.async {
                self?.state.toggleGlobalEnabled()
            }
        }
        shortcutMonitor.start()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        if !UserDefaults.standard.bool(forKey: "MousePortal.HasLaunched") {
            UserDefaults.standard.set(true, forKey: "MousePortal.HasLaunched")
            DispatchQueue.main.async { [weak self] in
                self?.editorWindowController.show()
            }
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !flag {
            editorWindowController.show()
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcutMonitor.stop()
        state.engine.stop()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func screenParametersChanged() {
        screenChangeWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.state.refreshDisplays()
        }
        screenChangeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: workItem)
    }
}
