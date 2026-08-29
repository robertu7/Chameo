import ChameoCore
import SwiftUI

struct MobileRootView: View {
    @Bindable var model: MobileAppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if model.requiresOnboarding {
                MobileOnboardingView(model: model)
            } else {
                MobileTabView(model: model)
            }
        }
        .onChange(of: scenePhase, initial: true) {
            guard scenePhase == .active else { return }
            model.permissions.refresh()
            if model.hasCompletedOnboarding {
                Task { await MobileReminderService.reconcileFromDefaults() }
            }
        }
    }
}

private struct MobileTabView: View {
    @Bindable var model: MobileAppModel

    var body: some View {
        TabView(selection: $model.selectedRoute) {
            Tab("Camera", systemImage: "camera", value: AppRoute.camera) {
                NavigationStack {
                    MobileCameraView()
                }
            }
            Tab("Library", systemImage: "calendar", value: AppRoute.library) {
                NavigationStack {
                    MobileLibraryView()
                }
            }
            Tab("Settings", systemImage: "gearshape", value: AppRoute.settings) {
                NavigationStack {
                    MobileSettingsView(model: model)
                }
            }
        }
    }
}
