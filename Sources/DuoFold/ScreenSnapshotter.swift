import AppKit
import CoreGraphics
import ScreenCaptureKit

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    /// The built-in display, or `nil` when only external displays are
    /// attached.
    static var builtIn: NSScreen? {
        screens.first { screen in
            guard let id = screen.displayID else { return false }
            return CGDisplayIsBuiltin(id) != 0
        }
    }
}

/// Keeps a recent screenshot of the built-in display ready.
///
/// Building an `SCContentFilter` enumerates every on-screen window, so the
/// filter is cached and rebuilt only when the display changes.
@MainActor
final class ScreenSnapshotter {

    private(set) var latestImage: CGImage?
    private(set) var latestScreen: NSScreen?

    private var filter: SCContentFilter?
    private var filterDisplayID: CGDirectDisplayID?
    private var timer: Timer?
    private var inFlight: Task<Void, Never>?
    private var lastLoggedGeometry: String?

    var isPrewarming: Bool { timer != nil }

    var hasPermission: Bool { CGPreflightScreenCaptureAccess() }

    /// Creates a neutral local image for Replay mode. It keeps the animation
    /// testable when Screen Recording is unavailable without pretending to be
    /// the user's desktop.
    static func makeReplayImage(for screen: NSScreen) -> CGImage? {
        let scale = min(max(screen.backingScaleFactor, 1), 2)
        let width = max(Int((screen.frame.width * scale).rounded()), 640)
        let height = max(Int((screen.frame.height * scale).rounded()), 420)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let colors = [
            CGColor(red: 0.08, green: 0.10, blue: 0.18, alpha: 1),
            CGColor(red: 0.22, green: 0.12, blue: 0.36, alpha: 1),
            CGColor(red: 0.04, green: 0.28, blue: 0.38, alpha: 1),
        ] as CFArray
        guard let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: colors,
            locations: [0, 0.55, 1]
        ) else { return nil }
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: CGFloat(width), y: CGFloat(height)),
            options: []
        )

        context.setLineWidth(max(1, CGFloat(width) / 900))
        context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.08))
        let step = max(CGFloat(width) / 12, 48)
        for x in stride(from: 0, through: CGFloat(width), by: step) {
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: CGFloat(height)))
        }
        for y in stride(from: 0, through: CGFloat(height), by: step) {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: CGFloat(width), y: y))
        }
        context.strokePath()

        return context.makeImage()
    }

    func beginPrewarm(interval: TimeInterval = 0.2) {
        guard timer == nil else { return }
        capture()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.capture() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func endPrewarm() {
        timer?.invalidate()
        timer = nil
    }

    func stop() {
        endPrewarm()
        inFlight?.cancel()
        inFlight = nil
        discard()
    }

    /// Drops the held screenshot.
    func discard() {
        latestImage = nil
        latestScreen = nil
    }

    /// Waits for a screenshot. A pre-warm capture already running counts.
    func captureOnce() async {
        await startCapture().value
    }

    /// Builds the capture filter without taking a screenshot.
    func warmFilter() async {
        guard let screen = NSScreen.builtIn, let displayID = screen.displayID else { return }
        if filter == nil || filterDisplayID != displayID {
            await rebuildFilter(displayID: displayID)
        }
    }

    private func capture() {
        startCapture()
    }

    @discardableResult
    private func startCapture() -> Task<Void, Never> {
        if let inFlight { return inFlight }
        let task = Task { [weak self] in
            await self?.performCapture()
            guard !Task.isCancelled else { return }
            self?.inFlight = nil
        }
        inFlight = task
        return task
    }

    private func performCapture() async {
        guard !Task.isCancelled else { return }
        // Do not invoke ScreenCaptureKit until access is granted. Repeated
        // failed calls can make macOS show the permission prompt on every poll.
        guard CGPreflightScreenCaptureAccess() else {
            Diagnostics.geometry.notice("capture skipped: screen recording permission is not granted")
            return
        }
        guard let screen = NSScreen.builtIn, let displayID = screen.displayID else { return }
        if filter == nil || filterDisplayID != displayID {
            await rebuildFilter(displayID: displayID)
        }
        guard !Task.isCancelled, let activeFilter = filter else { return }

        let configuration = SCStreamConfiguration()
        configuration.width = Int(activeFilter.contentRect.width * CGFloat(activeFilter.pointPixelScale))
        configuration.height = Int(activeFilter.contentRect.height * CGFloat(activeFilter.pointPixelScale))
        configuration.showsCursor = false
        configuration.captureResolution = .best
        configuration.scalesToFit = false

        do {
            let started = CFAbsoluteTimeGetCurrent()
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: activeFilter,
                configuration: configuration
            )
            guard !Task.isCancelled else { return }
            let elapsed = (CFAbsoluteTimeGetCurrent() - started) * 1000
            latestImage = image
            latestScreen = screen
            Diagnostics.geometry.debug("captureImage took \(elapsed, format: .fixed(precision: 1)) ms")
            let geometry = String(
                format: "screen %.0fx%.0f pt at (%.0f, %.0f), backingScale %.2f, contentRect %.0fx%.0f, pointPixelScale %.2f, requested %dx%d px, got %dx%d px",
                screen.frame.width, screen.frame.height,
                screen.frame.origin.x, screen.frame.origin.y,
                screen.backingScaleFactor,
                activeFilter.contentRect.width, activeFilter.contentRect.height,
                CGFloat(activeFilter.pointPixelScale),
                configuration.width, configuration.height,
                image.width, image.height
            )
            if geometry != lastLoggedGeometry {
                lastLoggedGeometry = geometry
                Diagnostics.geometry.notice("capture: \(geometry, privacy: .public)")
            }
        } catch {
            guard !Task.isCancelled else { return }
            Diagnostics.geometry.error("screenshot capture failed: \(String(describing: error), privacy: .public)")
            filter = nil
            filterDisplayID = nil
        }
    }

    private func rebuildFilter(displayID: CGDirectDisplayID) async {
        do {
            let started = CFAbsoluteTimeGetCurrent()
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            guard !Task.isCancelled else { return }
            Diagnostics.geometry.notice(
                "SCShareableContent took \((CFAbsoluteTimeGetCurrent() - started) * 1000, format: .fixed(precision: 1)) ms"
            )
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                filter = nil
                return
            }
            // Exclude ourselves, or a lingering overlay lands in the next snapshot.
            let bundleID = Bundle.main.bundleIdentifier
            let ownApplications = content.applications.filter { $0.bundleIdentifier == bundleID }
            filter = SCContentFilter(
                display: display,
                excludingApplications: ownApplications,
                exceptingWindows: []
            )
            filterDisplayID = displayID
        } catch {
            guard !Task.isCancelled else { return }
            filter = nil
            filterDisplayID = nil
        }
    }
}
