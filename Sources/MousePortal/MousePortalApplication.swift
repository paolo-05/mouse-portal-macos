import AppKit

@main
@MainActor
struct MousePortalApplication {
    static func main() {
        let application = NSApplication.shared
        let applicationDelegate = AppDelegate()
        application.delegate = applicationDelegate
        application.run()
        withExtendedLifetime(applicationDelegate) {}
    }
}
