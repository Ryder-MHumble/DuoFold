import AppKit
import Combine
import CoreGraphics

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var controller: LidController?
    private var statusItemController: StatusItemController?
    private var attentionMonitor: AttentionMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Diagnostics.geometry.notice(
            "launched bundle=\(Bundle.main.bundlePath, privacy: .public) identifier=\(Bundle.main.bundleIdentifier ?? "unknown", privacy: .public) screen recording granted=\(CGPreflightScreenCaptureAccess())"
        )
        let preferences = Preferences.shared
        let controller = LidController(preferences: preferences)
        self.controller = controller
        statusItemController = StatusItemController(controller: controller, preferences: preferences)
        controller.start()

        let attentionMonitor = AttentionMonitor()
        attentionMonitor.onFacingChanged = { [weak controller] facing in
            controller?.handleAttentionState(facing: facing)
        }
        self.attentionMonitor = attentionMonitor
        if preferences.attentionModeEnabled {
            Task { await attentionMonitor.start() }
        }
        preferences.$attentionModeEnabled
            .removeDuplicates()
            .sink { [weak attentionMonitor, weak controller] enabled in
                guard let attentionMonitor else { return }
                if enabled {
                    Task { await attentionMonitor.start() }
                } else {
                    attentionMonitor.stop()
                    controller?.handleAttentionState(facing: true)
                }
            }
            .store(in: &subscriptions)
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
        attentionMonitor?.stop()
    }

    private var subscriptions = Set<AnyCancellable>()
}
