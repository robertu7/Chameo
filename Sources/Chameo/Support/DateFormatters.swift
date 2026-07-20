import Foundation

enum DateFormatters {
    static var libraryDate: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = L10n.currentLocalization.displayLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    static var librarySectionDate: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = L10n.currentLocalization.displayLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    static var reminderPreview: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = L10n.currentLocalization.displayLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }

    static var longDate: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = L10n.currentLocalization.displayLocale
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }

    static var completeDate: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = L10n.currentLocalization.displayLocale
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }

    static var shortTime: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = L10n.currentLocalization.displayLocale
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }

    static var monthAndYear: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = L10n.currentLocalization.displayLocale
        formatter.setLocalizedDateFormatFromTemplate("MMMM y")
        return formatter
    }
}
