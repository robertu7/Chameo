import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab = ChameoTab.camera
    @Published var selectedLibraryDay: Date?
}

enum ChameoTab: String, CaseIterable, Identifiable {
    case camera
    case library

    var id: String { rawValue }

    var title: String {
        switch self {
        case .camera:
            return L10n.string("Camera")
        case .library:
            return L10n.string("Library")
        }
    }

    var systemImage: String {
        switch self {
        case .camera:
            return "camera"
        case .library:
            return "photo.on.rectangle"
        }
    }
}
