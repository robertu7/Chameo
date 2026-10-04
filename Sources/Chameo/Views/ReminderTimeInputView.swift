import SwiftUI

struct ReminderTimeInputView: View {
    @Binding var input: ReminderTimeInput
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            numberField(title: L10n.string("Hour"), text: $input.hourText,
                choices: input.hourChoices, padsWithZero: !input.usesTwelveHourClock)
            numberField(title: L10n.string("Minute"), text: $input.minuteText,
                choices: 0...59, padsWithZero: true)
            if input.usesTwelveHourClock {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.string("AM/PM")).font(.caption).foregroundStyle(.secondary)
                    Picker(L10n.string("AM/PM"), selection: $input.isPM) {
                        Text(periodFormatter.amSymbol).tag(false)
                        Text(periodFormatter.pmSymbol).tag(true)
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                }
            }
        }
        .monospacedDigit()
    }

    private func numberField(title: String, text: Binding<String>, choices: ClosedRange<Int>, padsWithZero: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                TextField(title, text: text)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .frame(width: 44)
                    .accessibilityLabel(title)
                Menu {
                    ForEach(Array(choices), id: \.self) { value in
                        let label = padsWithZero ? String(format: "%02d", value) : String(value)
                        Button(label) { text.wrappedValue = label }
                    }
                } label: {
                    Image(systemName: "chevron.down")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 18)
                .accessibilityLabel(title)
                .accessibilityValue(text.wrappedValue)
            }
        }
    }

    private var periodFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        return formatter
    }
}
