import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab = ChameoTab.camera
    @Published var selectedLibraryDay: Date?
    @Published var visibleMainSurface: ChameoMainSurface?
    private var preservesSelectionOnNextOpen = false

    var shouldRunCamera: Bool {
        visibleMainSurface != nil && selectedTab == .camera
    }

    func isCameraVisible(on surface: ChameoMainSurface) -> Bool {
        shouldRunCamera && visibleMainSurface == surface
    }

    func dismiss(_ surface: ChameoMainSurface) {
        if visibleMainSurface == surface { visibleMainSurface = nil }
    }

    func prepareForSettings() {
        preservesSelectionOnNextOpen = true
        visibleMainSurface = nil
    }

    func prepareForMenuBarOpen(status: DailyCaptureStatus, now: Date = Date()) {
        if preservesSelectionOnNextOpen {
            preservesSelectionOnNextOpen = false
            return
        }
        if status == .captured {
            selectedLibraryDay = Calendar.current.startOfDay(for: now)
            selectedTab = .library
        } else {
            selectedTab = .camera
        }
    }
}

enum ChameoMainSurface {
    case popover
    case standalone
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
