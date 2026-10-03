import SwiftUI

struct CaptureSettingsView: View {
    @AppStorage(AppPreferenceKey.handsFreeCountdown) private var handsFreeCountdown = false
    @AppStorage(AppPreferenceKey.showFaceGuide) private var showFaceGuide = true
    @AppStorage(AppPreferenceKey.autoAlignPhotos) private var autoAlignPhotos = true

    var body: some View {
        SettingsPage(title: L10n.string("Capture"), subtitle: L10n.string("Keep every Chameo consistent.")) {
            SettingsGroup {
                SettingsToggle(
                    title: L10n.string("Framing Guide"),
                    description: L10n.string("Helps position your face with live guidance."),
                    isOn: $showFaceGuide
                )

                if showFaceGuide {
                    Divider()
                    SettingsToggle(
                        title: L10n.string("Auto Capture"),
                        description: L10n.string(
                            "Captures after a three-second countdown when framing is ready."
                        ),
                        isOn: $handsFreeCountdown
                    )
                }

                Divider()
                SettingsToggle(
                    title: L10n.string("Face Alignment"),
                    description: L10n.string(
                        "Straightens and crops photos for consistent framing."
                    ),
                    isOn: $autoAlignPhotos
                )

            }
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

    private var isUsingDefaultCaptureSettings: Bool {
        showFaceGuide && !handsFreeCountdown && autoAlignPhotos
    }

    private func resetCaptureSettings() {
        showFaceGuide = true
        handsFreeCountdown = false
        autoAlignPhotos = true
    }
}
