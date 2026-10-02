import SwiftUI

struct CaptureSettingsView: View {
    @AppStorage(AppPreferenceKey.handsFreeCountdown) private var handsFreeCountdown = false
    @AppStorage(AppPreferenceKey.showFaceGuide) private var showFaceGuide = true
    @AppStorage(AppPreferenceKey.autoAlignPhotos) private var autoAlignPhotos = true

    var body: some View {
        Form {
            Section(L10n.string("Capture")) {
                SettingsToggle(
                    title: L10n.string("Framing Guide"),
                    description: L10n.string("Helps position your face with live guidance."),
                    isOn: $showFaceGuide
                )

                if showFaceGuide {
                    SettingsToggle(
                        title: L10n.string("Auto Capture"),
                        description: L10n.string(
                            "Captures after a three-second countdown when framing is ready."
                        ),
                        isOn: $handsFreeCountdown
                    )
                }

                SettingsToggle(
                    title: L10n.string("Face Alignment"),
                    description: L10n.string(
                        "Straightens and crops photos for consistent framing."
                    ),
                    isOn: $autoAlignPhotos
                )

                Button {
                    resetCaptureSettings()
                } label: {
                    Label(
                        L10n.string("Reset to Defaults"),
                        systemImage: "arrow.counterclockwise"
                    )
                }
                .disabled(isUsingDefaultCaptureSettings)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .formStyle(.grouped)
    }

    private var isUsingDefaultCaptureSettings: Bool {
        showFaceGuide && !handsFreeCountdown && autoAlignPhotos
    }

    private func resetCaptureSettings() {
        showFaceGuide = true
        handsFreeCountdown = false
        autoAlignPhotos = true
    }
}
