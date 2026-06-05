import Foundation

enum ReminderRepeat: String, CaseIterable, Identifiable {
    case none
    case daily
    case weekly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "None"
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        }
    }
}
