import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var localizationController: LocalizationController
    @AppStorage(AppPreferenceKey.hasCompletedPermissionOnboarding)
    private var hasCompletedPermissionOnboarding = false

    var body: some View {
        Group {
            if hasCompletedPermissionOnboarding {
                GeneralSettingsView()
            } else {
                ContentUnavailableView {
                    Label(L10n.string("Finish Chameo Setup"), systemImage: "lock.fill")
                } description: {
                    Text(L10n.string("Allow Camera and Photos access in the Chameo welcome window before opening Settings."))
                }
            }
        }
        .frame(width: 460, height: 360)
        .scenePadding()
        .environment(\.locale, localizationController.displayLocale)
    }
}
