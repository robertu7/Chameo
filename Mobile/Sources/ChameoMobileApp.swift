import SwiftUI

@main
struct ChameoMobileApp: App {
    @UIApplicationDelegateAdaptor(MobileNotificationDelegate.self) private var appDelegate
    @State private var model = MobileAppModel()

    var body: some Scene {
        WindowGroup {
            MobileRootView(model: model)
                .environment(model)
                .environment(\.locale, model.localization.displayLocale)
                .onOpenURL { _ in
                    model.route(to: .camera)
                }
                .onReceive(NotificationCenter.default.publisher(for: .openChameoCamera)) { _ in
                    model.route(to: .camera)
                }
        }
    }
}
