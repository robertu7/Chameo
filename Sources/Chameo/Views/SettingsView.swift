import SwiftUI

struct SettingsView: View {
    @AppStorage(AppPreferenceKey.hasCompletedPermissionOnboarding)
    private var hasCompletedPermissionOnboarding = false

    var body: some View {
        Group {
            if hasCompletedPermissionOnboarding {
                settingsTabs
            } else {
                ContentUnavailableView {
                    Label("Finish Chameo Setup", systemImage: "lock.fill")
                } description: {
                    Text("Allow Camera and Photos access in the Chameo welcome window before opening Settings.")
                }
            }
        }
        .frame(width: 460, height: 360)
        .scenePadding()
    }

    private var settingsTabs: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            ReminderSettingsView()
                .tabItem {
                    Label("Reminders", systemImage: "bell")
                }
        }
    }
}
