import SwiftUI
import UserNotifications

struct ReminderSettingsView: View {
    @AppStorage(AppPreferenceKey.reminderEnabled) private var reminderEnabledStorage = false
    @AppStorage(AppPreferenceKey.reminderDate) private var reminderDateTimeInterval = Date().timeIntervalSinceReferenceDate
    @AppStorage(AppPreferenceKey.reminderRepeat) private var reminderRepeatRawValue = ReminderRepeat.none.rawValue
    @AppStorage(AppPreferenceKey.reminderWeekday) private var reminderWeekdayStorage = Calendar.current.component(.weekday, from: Date())
    @AppStorage(AppPreferenceKey.reminderSettingsMigrated) private var reminderSettingsMigrated = false

    @State private var reminderEnabled = false
    @State private var reminderDate = Date()
    @State private var reminderRepeat = ReminderRepeat.none
    @State private var reminderWeekday = Calendar.current.component(.weekday, from: Date())
    @State private var isUpdatingReminder = false
    @State private var showsReminderProgress = false
    @State private var reminderProgressTask: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var notificationAuthorizationStatus = UNAuthorizationStatus.notDetermined
    @State private var hasLoadedSettings = false

    var body: some View {
        Form {
            Section("Reminders") {
                Toggle("Enable Reminders", isOn: $reminderEnabled)
                    .disabled(isUpdatingReminder)

                Picker("Repeats", selection: $reminderRepeat) {
                    ForEach(ReminderRepeat.allCases) { repeatMode in
                        Text(repeatMode.title).tag(repeatMode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!reminderEnabled || isUpdatingReminder)

                if reminderEnabled {
                    if reminderRepeat == .weekly {
                        Picker("Day", selection: $reminderWeekday) {
                            ForEach(1...7, id: \.self) { weekday in
                                Text(weekdayName(for: weekday)).tag(weekday)
                            }
                        }
                        .disabled(isUpdatingReminder)
                    }

                    if reminderRepeat == .none {
                        DatePicker("Date", selection: $reminderDate, displayedComponents: .date)
                            .disabled(isUpdatingReminder)
                    }

                    DatePicker("Time", selection: $reminderDate, displayedComponents: .hourAndMinute)
                        .disabled(isUpdatingReminder)
                }
            }

            Section {
                Text(reminderPreviewText)
                    .font(.caption)
                    .foregroundStyle(canSaveReminder ? Color.secondary : Color.red)

                HStack {
                    Button("Save Changes") {
                        Task {
                            await saveReminderSettings()
                        }
                    }
                    .disabled(!hasReminderChanges || !canSaveReminder || isUpdatingReminder)

                    Spacer()

                    if showsReminderProgress {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Updating reminder")
                    }
                }
            }

            if isNotificationPermissionDenied {
                PermissionStatusInline(
                    message: "Allow Notifications in System Settings to schedule reminders.",
                    destination: .notifications
                )
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
        .onAppear {
            if !hasLoadedSettings || !hasReminderChanges {
                loadStoredSettings()
                hasLoadedSettings = true
            }
            Task {
                await migrateReminderSettingsIfNeeded()
                notificationAuthorizationStatus = await ReminderService.authorizationStatus()
            }
        }
        .onDisappear {
            reminderProgressTask?.cancel()
        }
        .onChange(of: reminderEnabled) { _, newValue in
            guard newValue, reminderRepeat == .none, nextReminderDate == nil else {
                return
            }

            reminderDate = defaultOneTimeReminderDate
        }
    }

    private func loadStoredSettings() {
        reminderEnabled = reminderEnabledStorage
        reminderDate = Date(timeIntervalSinceReferenceDate: reminderDateTimeInterval)
        reminderRepeat = ReminderRepeat(rawValue: reminderRepeatRawValue) ?? .none
        reminderWeekday = validWeekday(reminderWeekdayStorage)
    }

    private func saveReminderSettings() async {
        errorMessage = nil
        isUpdatingReminder = true
        showReminderProgressAfterDelay()

        defer {
            reminderProgressTask?.cancel()
            reminderProgressTask = nil
            showsReminderProgress = false
            isUpdatingReminder = false
        }

        do {
            if reminderEnabled {
                try await ReminderService.configureReminder(
                    date: reminderDate,
                    repeatMode: reminderRepeat,
                    weekday: reminderWeekday
                )
            } else {
                try await ReminderService.cancelReminder()
            }

            reminderEnabledStorage = reminderEnabled
            reminderDateTimeInterval = reminderDate.timeIntervalSinceReferenceDate
            reminderRepeatRawValue = reminderRepeat.rawValue
            reminderWeekdayStorage = reminderWeekday
            notificationAuthorizationStatus = await ReminderService.authorizationStatus()
        } catch {
            notificationAuthorizationStatus = await ReminderService.authorizationStatus()
            errorMessage = error.localizedDescription
        }
    }

    private func showReminderProgressAfterDelay() {
        reminderProgressTask?.cancel()
        showsReminderProgress = false
        reminderProgressTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else {
                return
            }
            showsReminderProgress = true
        }
    }

    private var hasReminderChanges: Bool {
        reminderEnabled != reminderEnabledStorage
            || abs(reminderDate.timeIntervalSinceReferenceDate - reminderDateTimeInterval) > 1
            || reminderRepeat.rawValue != reminderRepeatRawValue
            || reminderWeekday != reminderWeekdayStorage
    }

    private var canSaveReminder: Bool {
        !reminderEnabled || nextReminderDate != nil
    }

    private var defaultOneTimeReminderDate: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }

    private var reminderPreviewText: String {
        guard reminderEnabled else {
            return "Reminders are off."
        }

        guard let nextReminderDate else {
            return "Choose a future time."
        }

        return "Next reminder: \(DateFormatters.reminderPreview.string(from: nextReminderDate))"
    }

    private var nextReminderDate: Date? {
        ReminderSchedule(
            date: reminderDate,
            repeatMode: reminderRepeat,
            weekday: reminderWeekday
        ).nextDate(after: Date())
    }

    private func weekdayName(for weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        guard symbols.indices.contains(weekday - 1) else {
            return ""
        }

        return symbols[weekday - 1]
    }

    private func validWeekday(_ weekday: Int) -> Int {
        let symbols = Calendar.current.weekdaySymbols
        guard symbols.indices.contains(weekday - 1) else {
            return Calendar.current.component(.weekday, from: reminderDate)
        }
        return weekday
    }

    private var isNotificationPermissionDenied: Bool {
        notificationAuthorizationStatus == .denied
    }

    private func migrateReminderSettingsIfNeeded() async {
        guard !reminderSettingsMigrated else {
            return
        }

        let hasScheduledReminder = await ReminderService.hasScheduledReminder()
        reminderEnabled = hasScheduledReminder
        reminderEnabledStorage = hasScheduledReminder
        reminderWeekday = Calendar.current.component(.weekday, from: reminderDate)
        reminderWeekdayStorage = reminderWeekday
        reminderSettingsMigrated = true
    }
}
