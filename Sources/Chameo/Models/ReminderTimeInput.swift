import Foundation

/// Text stays untouched while editing; menus and validation share the same values.
struct ReminderTimeInput {
    var hourText: String
    var minuteText: String
    var isPM: Bool
    let usesTwelveHourClock: Bool

    init(date: Date, calendar: Calendar = .current, locale: Locale = .current) {
        let pattern = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale) ?? "HH"
        usesTwelveHourClock = pattern.contains("h") || pattern.contains("K")
        let hour = calendar.component(.hour, from: date)
        isPM = hour >= 12
        hourText = usesTwelveHourClock ? String(hour % 12 == 0 ? 12 : hour % 12) : String(format: "%02d", hour)
        minuteText = String(format: "%02d", calendar.component(.minute, from: date))
    }

    var hourChoices: ClosedRange<Int> { usesTwelveHourClock ? 1...12 : 0...23 }

    var hour: Int? {
        guard let value = Self.number(in: hourText), hourChoices.contains(value) else { return nil }
        return usesTwelveHourClock ? value % 12 + (isPM ? 12 : 0) : value
    }

    var minute: Int? {
        guard let value = Self.number(in: minuteText), (0...59).contains(value) else { return nil }
        return value
    }

    mutating func selectHour(_ hour: Int) {
        guard (0...23).contains(hour) else {
            hourText = String(hour)
            return
        }
        isPM = hour >= 12
        hourText = usesTwelveHourClock ? String(hour % 12 == 0 ? 12 : hour % 12) : String(format: "%02d", hour)
    }

    private static func number(in text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...2).contains(trimmed.count) else { return nil }
        var value = 0
        for character in trimmed {
            guard character.isNumber, let digit = character.wholeNumberValue, (0...9).contains(digit) else { return nil }
            value = value * 10 + digit
        }
        return value
    }
}
