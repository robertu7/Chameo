import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            ReminderSettingsView()
            .tabItem {
                Label("Reminder", systemImage: "bell")
            }
        }
        .frame(width: 460, height: 360)
        .scenePadding()
    }
}
