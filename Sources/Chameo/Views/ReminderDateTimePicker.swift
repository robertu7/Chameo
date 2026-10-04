import SwiftUI

enum ReminderDateTimeComponent {
    case date, time

    var title: String { L10n.string(self == .date ? "Date" : "Time") }
    var symbol: String { self == .date ? "calendar" : "clock" }
}

struct ReminderDateTimePicker: View {
    @Binding var selection: Date
    let component: ReminderDateTimeComponent
    var repeatMode: ReminderRepeat = .daily
    var weekday: Int? = nil
    var onEditingChanged: (Bool) -> Void = { _ in }
    @State private var isPresented = false
    @State private var draft = ReminderDateTimeDraft(date: Date())

    private var formattedSelection: String {
        let formatter = component == .date ? DateFormatters.librarySectionDate : DateFormatters.shortTime
        return formatter.string(from: selection)
    }

    var body: some View {
        Button {
            draft = ReminderDateTimeDraft(date: selection, locale: L10n.currentLocalization.displayLocale)
            onEditingChanged(true)
            isPresented = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: component.symbol)
                Text(formattedSelection).monospacedDigit()
                Image(systemName: "chevron.down").font(.caption2)
            }
            .foregroundStyle(Color.primary)
        }
        .buttonStyle(.bordered)
        .fixedSize()
        .accessibilityLabel(component.title)
        .accessibilityValue(formattedSelection)
        .onChange(of: isPresented) { _, isPresented in
            if !isPresented { onEditingChanged(false) }
        }
        .onDisappear {
            if isPresented {
                isPresented = false
                onEditingChanged(false)
            }
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ReminderDateTimeEditor(draft: $draft, component: component, repeatMode: repeatMode, weekday: weekday,
                onCancel: { isPresented = false },
                onDone: {
                    guard draft.validationError(after: Date(), repeatMode: repeatMode, weekday: weekday) == nil,
                          let date = draft.scheduleDate(repeatMode: repeatMode) else { return }
                    selection = date
                    isPresented = false
                })
        }
    }
}

struct ReminderDateTimeEditor: View {
    @Binding var draft: ReminderDateTimeDraft
    let component: ReminderDateTimeComponent
    var repeatMode: ReminderRepeat = .daily
    var weekday: Int? = nil
    let onCancel: () -> Void
    let onDone: () -> Void
    @State private var now = Date()

    private var showsCalendar: Bool { repeatMode == .none || component == .date }

    private var validationError: ReminderDateTimeDraft.ValidationError? {
        draft.validationError(after: now, repeatMode: repeatMode, weekday: weekday)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(showsCalendar ? L10n.string("Date and time") : L10n.string("Time"))
                .font(.headline).accessibilityAddTraits(.isHeader)

            if showsCalendar {
                HStack(spacing: 8) {
                    Button(L10n.string("Today")) { draft.day = Date() }
                    Button(L10n.string("Tomorrow")) {
                        draft.day = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                    }
                }
                DatePicker(L10n.string("Date"), selection: $draft.day,
                    in: Calendar.current.startOfDay(for: now)..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
            }

            ReminderTimeInputView(input: $draft.time)

            if let validationError {
                Text(validationMessage(for: validationError))
                    .font(.callout).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let nextDate = draft.nextDate(after: now, repeatMode: repeatMode, weekday: weekday) {
                Text(L10n.format("Next reminder: %@", DateFormatters.reminderPreview.string(from: nextDate)))
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button(L10n.string("Cancel"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(L10n.string("Done"), action: commit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(validationError != nil)
            }
        }
        .padding(16)
        .frame(width: 300)
        .onSubmit(commit)
        .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { now = $0 }
    }

    private func commit() {
        now = Date()
        guard draft.validationError(after: now, repeatMode: repeatMode, weekday: weekday) == nil else { return }
        onDone()
    }

    private func validationMessage(for error: ReminderDateTimeDraft.ValidationError) -> String {
        switch error {
        case .invalidTime:
            return L10n.string(draft.time.usesTwelveHourClock
                ? "Enter an hour from 1 to 12 and a minute from 0 to 59."
                : "Enter an hour from 0 to 23 and a minute from 0 to 59.")
        case .unavailableTime:
            return L10n.string("This time is unavailable on this date. Choose another time.")
        case .pastDate:
            return L10n.string("Choose a future time.")
        }
    }
}
