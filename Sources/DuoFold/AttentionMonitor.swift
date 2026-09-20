import AVFoundation
import QuartzCore
import Vision

/// Local-only face-orientation monitor for the optional attention mode.
/// Frames are analyzed in memory and are never written or uploaded.
final class AttentionMonitor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    var onFacingChanged: (@MainActor (Bool) -> Void)?
    var onStatusChanged: (@MainActor (String) -> Void)?

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "DuoFold.attention", qos: .userInitiated)
    private var lastFacing: Bool?
    private var candidateFacing: Bool?
    private var candidateSince: CFTimeInterval?
    private var lastAnalysis = CACurrentMediaTime()
    private var requestingAccess = false

    func start() async {
        guard !requestingAccess, !session.isRunning else { return }
        requestingAccess = true
        defer { requestingAccess = false }
        // This method is called from AppDelegate's main-actor Task. Requesting
        // access directly here ensures macOS can present its TCC prompt.
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            report("camera permission denied")
            return
        }
        queue.async { [weak self] in self?.configureAndStart() }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
            self.lastFacing = nil
            self.candidateFacing = nil
            self.candidateSince = nil
            self.report("stopped")
        }
    }

    private func configureAndStart() {
        guard !session.isRunning else { return }
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .front
        )
        guard let device = discovery.devices.first,
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            report("camera unavailable")
            return
        }
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        guard session.canAddOutput(output) else { return }
        session.beginConfiguration()
        session.sessionPreset = .vga640x480
        session.addInput(input)
        session.addOutput(output)
        output.setSampleBufferDelegate(self, queue: queue)
        session.commitConfiguration()
        session.startRunning()
        report("running")
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        guard now - lastAnalysis >= 0.2 else { return }
        lastAnalysis = now
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: imageBuffer, orientation: .leftMirrored)
        try? handler.perform([request])
        let face = request.results?.max { $0.boundingBox.width < $1.boundingBox.width }
        // Some camera drivers omit pose metadata even when a face is found.
        // Treat an omitted pose as neutral instead of classifying every frame
        // as "looking away".
        let yaw = face?.yaw?.doubleValue ?? 0
        let roll = face?.roll?.doubleValue ?? 0
        let facing = face != nil && abs(yaw) < 0.48 && abs(roll) < 0.55
        if facing != candidateFacing {
            candidateFacing = facing
            candidateSince = now
            return
        }
        guard let candidateSince, now - candidateSince >= 0.6, facing != lastFacing else { return }
        lastFacing = facing
        report(facing ? "facing screen" : "looking away")
        Task { @MainActor [weak self] in
            self?.onFacingChanged?(facing)
        }
    }

    private func report(_ message: String) {
        Diagnostics.geometry.notice("attention: \(message, privacy: .public)")
        Task { @MainActor [weak self] in self?.onStatusChanged?(message) }
    }
}
