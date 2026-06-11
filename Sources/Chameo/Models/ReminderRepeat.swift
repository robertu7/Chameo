import Foundation

enum ReminderRepeat: String, CaseIterable, Identifiable {
    case none
    case daily
    case weekly

    static var allCases: [ReminderRepeat] {
        [.daily, .weekly, .none]
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "Once"
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        }
    }
}
