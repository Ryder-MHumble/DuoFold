import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var controller: LidController

    /// Empty means following the system language.
    @AppStorage("settingsLanguage") private var language = ""

    private var selectedLanguage: SettingsLanguage {
        SettingsLanguage(rawValue: language) ?? .preferred
    }

    private func localized(_ key: String) -> String {
        selectedLanguage.localized(key)
    }

    @State private var launchesAtLogin = SMAppService.mainApp.status == .enabled
    @State private var hasScreenPermission = CGPreflightScreenCaptureAccess()
    @State private var settingsOpenFailed = false
    @State private var advancedBehaviorExpanded = false
    @State private var advancedAppearanceExpanded = false
    @State private var resetHovered = false
    @State private var quitHovered = false

    var onQuit: () -> Void

    private static let width: CGFloat = 320
    private static let bodyHeight: CGFloat = 430
    private static let screenRecordingSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture"
    )!

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            if controller.isSensorAvailable {
                Form {
                    Section {
                        Toggle(localized("Depth effect"), isOn: $preferences.isEnabled)
                        Toggle(localized("Live rendering"), isOn: $preferences.isLivePicture)
                            .disabled(!preferences.isEnabled)
                        effectPicker
                    } header: {
                        Text(localized("Effect"))
                    }

                    if !hasScreenPermission {
                        Section {
                            permissionNotice
                        }
                    }

                    Section {
                        Toggle(localized("Clear when the lid is still"), isOn: $preferences.isTimeoutEnabled)
                        Picker(localized("Start angle"), selection: startAnglePreset) {
                            Text("60°").tag(60)
                            Text("75°").tag(75)
                            Text("90°").tag(90)
                            Text("105°").tag(105)
                        }
                        Picker(localized("Full effect after"), selection: blurSpanPreset) {
                            Text("30°").tag(30)
                            Text("45°").tag(45)
                            Text("60°").tag(60)
                        }
                        advancedToggle(localized("Advanced tuning"), isExpanded: $advancedBehaviorExpanded) {
                            slider(localized("Start angle"), value: $preferences.thresholdAngle, in: 5...130, format: "%.0f°")
                            slider(localized("Full effect after"), value: $preferences.blurSpan, in: 5...60, format: "%.0f°")
                        }
                    } header: {
                        Text(localized("Behavior"))
                    }
                    .disabled(!preferences.isEnabled)

                    Section {
                        Picker(localized("Blur"), selection: blurPreset) {
                            Text(localized("Soft")).tag(0)
                            Text(localized("Balanced")).tag(1)
                            Text(localized("Strong")).tag(2)
                        }
                        Picker(localized("Dimming"), selection: dimPreset) {
                            Text(localized("Light")).tag(0)
                            Text(localized("Balanced")).tag(1)
                            Text(localized("Dark")).tag(2)
                        }
                        Picker(localized("Perspective"), selection: perspectivePreset) {
                            Text(localized("Flat")).tag(0)
                            Text(localized("Natural")).tag(1)
                            Text(localized("Physical")).tag(2)
                        }
                        advancedToggle(localized("Advanced tuning"), isExpanded: $advancedAppearanceExpanded) {
                            slider(localized("Blur"), value: $preferences.maxBlurRadius, in: 10...160, format: "%.0f pt")
                            slider(localized("Dimming"), value: $preferences.maxDim, in: 0...1, format: "%.0f%%", scale: 100)
                            slider(localized("Perspective"), value: perspective, in: 0...1, format: "%.0f%%", scale: 100)
                        }
                    } header: {
                        Text(localized("Appearance"))
                    }
                    .disabled(!preferences.isEnabled)

                    Section {
                        Toggle(localized("Show angle in menu bar"), isOn: $preferences.showsAngleInMenuBar)
                        Toggle(localized("Launch at login"), isOn: $launchesAtLogin)
                            .onChange(of: launchesAtLogin) { _, newValue in setLaunchAtLogin(newValue) }
                        Picker(localized("Language"), selection: $language) {
                            Text(localized("System")).tag("")
                            Text(verbatim: "English").tag(SettingsLanguage.english.rawValue)
                            Text(localized("Chinese (Simplified)")).tag(SettingsLanguage.chinese.rawValue)
                        }
                    } header: {
                        Text(localized("General"))
                    }
                }
                .frame(height: Self.bodyHeight)
                .formStyle(.grouped)
            } else {
                unavailableNotice
                    .padding(16)
            }
            HStack {
                Text(localized("Developed by Ryder"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button { preferences.resetToDefaults() } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(resetHovered ? .primary : .secondary)
                .scaleEffect(resetHovered ? 1.12 : 1)
                .opacity(resetHovered ? 1 : 0.72)
                .animation(.easeOut(duration: 0.16), value: resetHovered)
                .onHover { resetHovered = $0 }
                .accessibilityLabel(localized("Reset"))
                .help(localized("Reset"))
                Button(action: onQuit) {
                    Image(systemName: "power")
                }
                    .buttonStyle(.borderless)
                    .foregroundStyle(quitHovered ? .red : .secondary)
                    .scaleEffect(quitHovered ? 1.12 : 1)
                    .opacity(quitHovered ? 1 : 0.72)
                    .animation(.easeOut(duration: 0.16), value: quitHovered)
                    .onHover { quitHovered = $0 }
                    .accessibilityLabel(localized("Quit"))
                    .help(localized("Quit"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: Self.width)
        .onAppear {
            hasScreenPermission = CGPreflightScreenCaptureAccess()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasScreenPermission = CGPreflightScreenCaptureAccess()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.inset.filled.and.person.filled")
                .font(.title3)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text("DuoFold").font(.headline)
                Text(controller.isSensorAvailable ? localized("Ready") : localized("Sensor unavailable"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(String(format: "%.1f°", controller.currentAngle))
                .font(.system(.body, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityLabel(localized("Lid angle"))
        }
    }

    private var unavailableNotice: some View {
        Text(localized("This Mac has no lid angle sensor. Only some MacBook models have one."))
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var effectPicker: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Picker(localized("Animation"), selection: $preferences.selectedEffect) {
                    ForEach(DuoFoldEffect.allCases) { effect in
                        Text(localized(effect.displayNameKey)).tag(effect)
                    }
                }
                Button {
                    controller.runPreview()
                } label: {
                    Image(systemName: "play.circle")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help(localized("Preview"))
                .accessibilityLabel(localized("Preview"))
                .disabled(!preferences.isEnabled)
            }
            Text(localized(preferences.selectedEffect.descriptionKey))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func advancedToggle<Content: View>(
        _ title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                isExpanded.wrappedValue.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        if isExpanded.wrappedValue {
            content()
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var startAnglePreset: Binding<Int> {
        Binding(
            get: { Int(preferences.thresholdAngle.rounded()) },
            set: { preferences.thresholdAngle = Double($0) }
        )
    }

    private var blurSpanPreset: Binding<Int> {
        Binding(
            get: { Int(preferences.blurSpan.rounded()) },
            set: { preferences.blurSpan = Double($0) }
        )
    }

    private var blurPreset: Binding<Int> {
        Binding(
            get: { preferences.maxBlurRadius < 70 ? 0 : preferences.maxBlurRadius < 120 ? 1 : 2 },
            set: { preferences.maxBlurRadius = [45, 90, 135][$0] }
        )
    }

    private var dimPreset: Binding<Int> {
        Binding(
            get: { preferences.maxDim < 0.35 ? 0 : preferences.maxDim < 0.75 ? 1 : 2 },
            set: { preferences.maxDim = [0.25, 0.55, 0.9][$0] }
        )
    }

    private var perspectivePreset: Binding<Int> {
        Binding(
            get: { perspective.wrappedValue < 0.34 ? 0 : perspective.wrappedValue < 0.67 ? 1 : 2 },
            set: { perspective.wrappedValue = [0.15, 0.5, 0.85][$0] }
        )
    }

    private var perspective: Binding<Double> {
        Binding(
            get: { (Preferences.farthestEye - preferences.viewingDistance) / Preferences.eyeRange },
            set: { preferences.viewingDistance = Preferences.farthestEye - $0 * Preferences.eyeRange }
        )
    }

    private var permissionNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localized("Screen Recording permission is required to show the depth effect."))
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Text(localized("After enabling DuoFold in System Settings, quit and reopen the app."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(localized("Open System Settings")) {
                    openScreenRecordingSettings()
                }
                .controlSize(.small)
            }
            if settingsOpenFailed {
                Text(localized("Could not open System Settings. Open it manually and enable screen recording for DuoFold under Privacy & Security."))
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func openScreenRecordingSettings() {
        settingsOpenFailed = false
        // This establishes the TCC request for the exact bundle currently
        // running. The user still confirms the switch in System Settings.
        _ = CGRequestScreenCaptureAccess()
        Task { @MainActor in
            do {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                _ = try await NSWorkspace.shared.open(Self.screenRecordingSettingsURL, configuration: configuration)
            } catch {
                settingsOpenFailed = true
            }
        }
    }

    private func slider(
        _ title: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        format: String,
        scale: Double = 1
    ) -> some View {
        let reading = String(format: format, value.wrappedValue * scale)
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(reading)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
                .labelsHidden()
                .controlSize(.small)
                .accessibilityLabel(title)
                .accessibilityValue(reading)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchesAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
