import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: SettingsState
    @EnvironmentObject private var localizationController: LocalizationController
    @AppStorage(AppPreferenceKey.hasCompletedPermissionOnboarding)
    private var hasCompletedPermissionOnboarding = false

    var body: some View {
        Group {
            if hasCompletedPermissionOnboarding {
                TabView(selection: $state.category) {
                    GeneralSettingsView()
                        .tabItem { categoryLabel(.general) }.tag(SettingsCategory.general)
                    CaptureSettingsView()
                        .tabItem { categoryLabel(.capture) }.tag(SettingsCategory.capture)
                    ReminderSettingsView()
                        .tabItem { categoryLabel(.reminders) }.tag(SettingsCategory.reminders)
                    PhotosSettingsView()
                        .tabItem { categoryLabel(.photos) }.tag(SettingsCategory.photos)
                }
                .tabViewStyle(.grouped)
            } else {
                ContentUnavailableView {
                    Label(L10n.string("Finish Chameo Setup"), systemImage: "lock.fill")
                } description: {
                    Text(L10n.string("Allow Camera and Photos access in the Chameo welcome window before opening Settings."))
                }
            }
        }
        .environment(\.locale, localizationController.displayLocale)
    }

    private func categoryLabel(_ category: SettingsCategory) -> some View {
        Text(category.title)
    }
}
