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
            return L10n.string("Once")
        case .daily:
            return L10n.string("Daily")
        case .weekly:
            return L10n.string("Weekly")
        }
    }
}
