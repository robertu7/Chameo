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
    @State private var reminderUpdateTask: Task<Void, Never>?
    @State private var reminderProgressTask: Task<Void, Never>?
    @State private var errorMessage: LocalizedMessage?
    @State private var notificationAuthorizationStatus = UNAuthorizationStatus.notDetermined
    @State private var hasLoadedSettings = false

    var body: some View {
        Section {
            Toggle(L10n.string("Enable Reminders"), isOn: $reminderEnabled)
                .disabled(isUpdatingReminder)

            if reminderEnabled {
                Picker(L10n.string("Frequency"), selection: $reminderRepeat) {
                    ForEach(ReminderRepeat.allCases) { repeatMode in
                        Text(repeatMode.title).tag(repeatMode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(isUpdatingReminder)

                if reminderRepeat == .weekly {
                    Picker(L10n.string("Day"), selection: $reminderWeekday) {
                        ForEach(1...7, id: \.self) { weekday in
                            Text(weekdayName(for: weekday)).tag(weekday)
                        }
                    }
                    .disabled(isUpdatingReminder)
                }

                if reminderRepeat == .none {
                    DatePicker(L10n.string("Date"), selection: $reminderDate, displayedComponents: .date)
                        .disabled(isUpdatingReminder)
                }

                DatePicker(
                    selection: $reminderDate,
                    displayedComponents: .hourAndMinute
                ) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.string("Time"))

                        HStack(spacing: 6) {
                            Text(reminderPreviewText)
                                .font(.caption)
                                .foregroundStyle(canSaveReminder ? Color.secondary : Color.red)

                            if showsReminderProgress {
                                ProgressView()
                                    .controlSize(.small)
                                    .accessibilityLabel(L10n.string("Updating reminder"))
                            }
                        }
                    }
                }
                .disabled(isUpdatingReminder)
                .accessibilityLabel(L10n.string("Time"))
                .accessibilityValue(reminderPreviewText)
                .accessibilityHint(reminderPreviewText)
            }

            if isNotificationPermissionDenied {
                PermissionStatusInline(
                    message: L10n.string("Allow Notifications in System Settings to schedule reminders."),
                    destination: .notifications
                )
            }

            if let errorMessage {
                Text(errorMessage.text)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        } header: {
            Text(L10n.string("Reminders"))
        } footer: {
            if !reminderEnabled {
                Text(reminderPreviewText)
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
            if newValue, reminderRepeat == .none, nextReminderDate == nil {
                reminderDate = defaultOneTimeReminderDate
            }

            scheduleReminderUpdate()
        }
        .onChange(of: reminderDate) {
            scheduleReminderUpdate()
        }
        .onChange(of: reminderRepeat) {
            scheduleReminderUpdate()
        }
        .onChange(of: reminderWeekday) {
            scheduleReminderUpdate()
        }
        .onChange(of: errorMessage?.text) { _, newValue in
            guard let newValue else {
                return
            }

            AccessibilityAnnouncement.post(newValue, priority: .high)
        }
    }

    private func loadStoredSettings() {
        reminderEnabled = reminderEnabledStorage
        reminderDate = Date(timeIntervalSinceReferenceDate: reminderDateTimeInterval)
        reminderRepeat = ReminderRepeat(rawValue: reminderRepeatRawValue) ?? .none
        reminderWeekday = validWeekday(reminderWeekdayStorage)
    }

    private func saveReminderSettings() async {
        guard hasReminderChanges, canSaveReminder, !isUpdatingReminder else {
            return
        }

        errorMessage = nil
        isUpdatingReminder = true
        showReminderProgressAfterDelay()

        defer {
            reminderProgressTask?.cancel()
            reminderProgressTask = nil
            reminderUpdateTask = nil
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
            errorMessage = .error(error)
        }
    }

    private func scheduleReminderUpdate() {
        reminderUpdateTask?.cancel()
        reminderUpdateTask = nil

        guard hasLoadedSettings else {
            return
        }

        errorMessage = nil
        guard hasReminderChanges else {
            return
        }

        guard canSaveReminder else {
            return
        }

        reminderUpdateTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else {
                return
            }
            await saveReminderSettings()
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
            return L10n.string("Reminders are off.")
        }

        guard let nextReminderDate else {
            return L10n.string("Choose a future time.")
        }

        return L10n.format(
            "Next reminder: %@",
            DateFormatters.reminderPreview.string(from: nextReminderDate)
        )
    }

    private var nextReminderDate: Date? {
        ReminderSchedule(
            date: reminderDate,
            repeatMode: reminderRepeat,
            weekday: reminderWeekday
        ).nextDate(after: Date())
    }

    private func weekdayName(for weekday: Int) -> String {
        let symbols = localizedCalendar.weekdaySymbols
        guard symbols.indices.contains(weekday - 1) else {
            return ""
        }

        return symbols[weekday - 1]
    }

    private func validWeekday(_ weekday: Int) -> Int {
        let symbols = localizedCalendar.weekdaySymbols
        guard symbols.indices.contains(weekday - 1) else {
            return Calendar.current.component(.weekday, from: reminderDate)
        }
        return weekday
    }

    private var isNotificationPermissionDenied: Bool {
        notificationAuthorizationStatus == .denied
    }

    private var localizedCalendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = L10n.currentLocalization.displayLocale
        return calendar
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
