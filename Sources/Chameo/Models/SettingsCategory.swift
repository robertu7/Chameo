enum SettingsCategory: String, CaseIterable, Identifiable {
    case general
    case capture
    case reminders
    case photos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: L10n.string("General")
        case .capture: L10n.string("Capture")
        case .reminders: L10n.string("Reminders")
        case .photos: L10n.string("Photos")
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .capture: "camera"
        case .reminders: "bell"
        case .photos: "photo.on.rectangle"
        }
    }
}
