import Foundation

/// Shared effect contract used by the lid policy and renderer.
/// Platform renderers consume this value without depending on sensor APIs.
enum DuoFoldEffect: String, CaseIterable, Codable, Identifiable {
    case duo, ghost, roll, shutter, flex, iris, replay

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .duo: "Duo"
        case .ghost: "Ghost"
        case .roll: "Roll"
        case .shutter: "Shutter"
        case .flex: "Flex"
        case .iris: "Iris"
        case .replay: "Replay"
        }
    }

    var displayNameKey: String { "Effect.\(rawValue).name" }
    var descriptionKey: String { "Effect.\(rawValue).description" }

    var shaderIndex: Int {
        // Stable contract copied from DhananjayBhosale/MacDuo.
        switch self {
        case .duo: 0
        case .roll: 1
        case .shutter: 2
        case .flex: 3
        case .iris: 4
        case .ghost: 5
        case .replay: 0
        }
    }
}

/// Renderer-neutral inputs. Values are normalized so Metal, D3D, and future
/// preview renderers can share the same animation state.
struct EffectFrame: Equatable {
    var progress: Double = 0
    var lidAngle: Double = 180
    var easing: Double = 1
    var blurRadius: Double = 0
    var coverage: Double = 0
    var perspective: Double = 0.5
    var direction: Double = 1
    var reducedMotion = false

    func clamped() -> EffectFrame {
        var result = self
        result.progress = progress.clamped(to: 0...1)
        result.lidAngle = lidAngle.clamped(to: 0...180)
        result.easing = easing.clamped(to: 0...1)
        result.blurRadius = blurRadius.clamped(to: 0...1)
        result.coverage = coverage.clamped(to: 0...1)
        result.perspective = perspective.clamped(to: 0...1)
        result.direction = direction < 0 ? -1 : 1
        return result
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
