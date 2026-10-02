import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var localizationController: LocalizationController
    @EnvironmentObject private var updateController: UpdateController
    @AppStorage(AppPreferenceKey.launchAtLogin) private var storedLaunchAtLogin = false
    @State private var launchAtLogin = false
    @State private var isUpdatingLaunchAtLogin = false
    @State private var isLoadingSettings = true
    @State private var errorMessage: LocalizedMessage?

    var body: some View {
        Form {
            Section {
                Picker(
                    L10n.string("settings.language.picker"),
                    selection: languageBinding
                ) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.pickerTitle).tag(language)
                    }
                }

                if AppDistribution.current.launchAtLoginEnabled {
                    Toggle(L10n.string("Launch at Login"), isOn: $launchAtLogin)
                        .disabled(isUpdatingLaunchAtLogin)
                }

                if updateController.isEnabled {
                    Toggle(
                        L10n.string("Automatically Check for Updates"),
                        isOn: automaticUpdateChecksBinding
                    )

                    Button(L10n.string("Check for Updates…")) {
                        updateController.checkForUpdates()
                    }
                    .disabled(!updateController.canCheckForUpdates)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } header: {
                Text(L10n.string("App"))
            } footer: {
                Text(buildInformation)
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            if let errorMessage { SettingsErrorView(message: errorMessage.text) }
        }
        .onAppear {
            isLoadingSettings = true
            launchAtLogin = AppDistribution.current.launchAtLoginEnabled && LaunchAtLoginService.isEnabled
            storedLaunchAtLogin = launchAtLogin
            isLoadingSettings = false
        }
        .onChange(of: launchAtLogin) { _, value in
            guard AppDistribution.current.launchAtLoginEnabled,
                  !isLoadingSettings, value != LaunchAtLoginService.isEnabled else { return }
            Task { await updateLaunchAtLogin(value) }
        }
        .onChange(of: errorMessage?.text) { _, text in
            if let text { AccessibilityAnnouncement.post(text, priority: .high) }
        }
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { localizationController.preference },
            set: { localizationController.select($0) }
        )
    }

    private var automaticUpdateChecksBinding: Binding<Bool> {
        Binding(
            get: { updateController.automaticallyChecksForUpdates },
            set: { updateController.setAutomaticallyChecksForUpdates($0) }
        )
    }

    private var buildInformation: String {
        if AppDistribution.current.isTestBuild {
            return L10n.format(
                "Version %@ · Build %@ · Test build",
                AppVersion.current.version,
                AppVersion.current.buildID
            )
        }

        return L10n.format(
            "Version %@ · Build %@",
            AppVersion.current.version,
            AppVersion.current.buildID
        )
    }

    private func updateLaunchAtLogin(_ isEnabled: Bool) async {
        errorMessage = nil
        isUpdatingLaunchAtLogin = true

        do {
            try LaunchAtLoginService.setEnabled(isEnabled)
            if isEnabled && LaunchAtLoginService.requiresApproval {
                errorMessage = .localized("Open System Settings → General → Login Items, then allow Chameo.")
            }
            launchAtLogin = LaunchAtLoginService.isEnabled
            storedLaunchAtLogin = launchAtLogin
        } catch {
            launchAtLogin = LaunchAtLoginService.isEnabled
            storedLaunchAtLogin = launchAtLogin
            errorMessage = .error(error)
        }

        isUpdatingLaunchAtLogin = false
    }
}
