import SwiftUI

struct SettingsView: View {
    enum Layout {
        case embedded
        case window
    }

    @EnvironmentObject private var localizationController: LocalizationController
    @AppStorage(AppPreferenceKey.hasCompletedPermissionOnboarding)
    private var hasCompletedPermissionOnboarding = false

    let layout: Layout

    init(layout: Layout = .window) {
        self.layout = layout
    }

    var body: some View {
        Group {
            switch layout {
            case .embedded:
                settingsContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .window:
                settingsContent
                    .frame(width: 460, height: 360)
                    .scenePadding()
            }
        }
        .environment(\.locale, localizationController.displayLocale)
    }

    @ViewBuilder
    private var settingsContent: some View {
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
    }
}
