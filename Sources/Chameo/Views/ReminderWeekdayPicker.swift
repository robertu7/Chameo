import SwiftUI

struct ReminderWeekdayPicker: View {
    @Binding var selection: Int
    @Environment(\.locale) private var locale

    var body: some View {
        HStack {
            Text(L10n.string("Day"))
            Spacer()
            Picker(L10n.string("Day"), selection: $selection) {
                ForEach(1...7, id: \.self) { weekday in
                    Text(weekdayNames[weekday - 1]).tag(weekday)
                }
            }
            .labelsHidden().pickerStyle(.menu).fixedSize()
        }
    }

    private var weekdayNames: [String] {
        var calendar = Calendar.current
        calendar.locale = locale
        return calendar.weekdaySymbols
    }
}
