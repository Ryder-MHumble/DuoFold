# Platform architecture

DuoFold keeps the product state machine independent from hardware and GPU APIs.
The current macOS implementation remains native and uses:

- IOKit/HID for continuous lid-angle samples.
- ScreenCaptureKit for an in-memory desktop frame.
- Metal for perspective, blur, dimming, and overlay composition.
- AppKit/SwiftUI for the menu bar and settings window.

The renderer-neutral boundary is represented by `LidSensorProviding`,
`DesktopCaptureProviding`, `EffectRendering`, `DuoFoldEffect`, and
`EffectFrame` in `Sources/DuoFold`.

A future Windows adapter should use Raw HID/ACPI or a vendor sensor API,
Windows Graphics Capture/Desktop Duplication, and Direct3D with
DirectComposition. Devices without a continuous hinge sensor should expose a
manual progress control or a simple open/closed fallback. Windows support must
be validated on real hardware because sensor protocols are vendor-specific.

Desktop frames remain local. Any future platform adapter must preserve the same
privacy boundary and must fail clear when capture, permission, or sensor access
is unavailable.
