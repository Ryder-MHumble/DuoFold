import AppKit
import Combine
import CoreGraphics

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var controller: LidController?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Diagnostics.geometry.notice(
            "launched bundle=\(Bundle.main.bundlePath, privacy: .public) identifier=\(Bundle.main.bundleIdentifier ?? "unknown", privacy: .public) screen recording granted=\(CGPreflightScreenCaptureAccess())"
        )
        let preferences = Preferences.shared
        let controller = LidController(preferences: preferences)
        self.controller = controller
        statusItemController = StatusItemController(controller: controller, preferences: preferences)
        controller.start()

    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }

    private var subscriptions = Set<AnyCancellable>()
}
