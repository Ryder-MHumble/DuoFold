import Foundation

/// Platform boundary for the shared DuoFold state machine.
/// macOS currently supplies IOKit and ScreenCaptureKit implementations;
/// Windows can provide Raw HID/ACPI and Windows Graphics Capture adapters.
protocol LidSensorProviding: AnyObject {
    var isAvailable: Bool { get }
    var angle: Double { get }
    func start() async
    func stop()
}

protocol DesktopCaptureProviding: AnyObject {
    func requestPermission() async -> Bool
    func capture() async throws -> CapturedFrame
}

protocol EffectRendering: AnyObject {
    func render(effect: DuoFoldEffect, frame: EffectFrame)
}
