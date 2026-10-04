import SwiftUI
import UserNotifications

struct ReminderSettingsView: View {
    @AppStorage(AppPreferenceKey.reminderEnabled) private var reminderEnabledStorage = false
    @AppStorage(AppPreferenceKey.reminderDate) private var reminderDateTimeInterval = Date().timeIntervalSinceReferenceDate
    @AppStorage(AppPreferenceKey.reminderRepeat) private var reminderRepeatRawValue = ReminderRepeat.none.rawValue
    @AppStorage(AppPreferenceKey.reminderWeekday) private var reminderWeekdayStorage = Calendar.current.component(.weekday, from: Date())

    @State private var reminderEnabled = false
    @State private var reminderDate = Date()
    @State private var reminderRepeat = ReminderRepeat.none
    @State private var reminderWeekday = Calendar.current.component(.weekday, from: Date())
    @State private var isUpdatingReminder = false
    @State private var isEditingReminderDateTime = false
    @State private var showsReminderProgress = false
    @State private var reminderUpdateTask: Task<Void, Never>?
    @State private var reminderProgressTask: Task<Void, Never>?
    @State private var errorMessage: LocalizedMessage?
    @State private var notificationAuthorizationStatus = UNAuthorizationStatus.notDetermined
    @State private var hasLoadedSettings = false

    var body: some View {
        SettingsPage(title: L10n.string("Reminders"), subtitle: L10n.string("A gentle nudge for your daily photo.")) {
            SettingsGroup {
                SettingsToggle(title: L10n.string("Enable Reminders"), isOn: $reminderEnabled)
                    .disabled(isUpdatingReminder)

                if reminderEnabled {
                    Divider()
                    HStack {
                        Text(L10n.string("Frequency"))
                        Spacer()
                        Picker(L10n.string("Frequency"), selection: $reminderRepeat) {
                            ForEach(ReminderRepeat.allCases) { repeatMode in Text(repeatMode.title).tag(repeatMode) }
                        }
                        .labelsHidden().pickerStyle(.menu).fixedSize().disabled(isUpdatingReminder)
                    }

                    if reminderRepeat == .weekly {
                        ReminderWeekdayPicker(selection: $reminderWeekday)
                            .disabled(isUpdatingReminder)
                    }

                    if reminderRepeat == .none {
                        HStack {
                            Text(L10n.string("Date"))
                            Spacer()
                            ReminderDateTimePicker(selection: $reminderDate, component: .date,
                                repeatMode: reminderRepeat, weekday: reminderWeekday,
                                onEditingChanged: { isEditingReminderDateTime = $0 })
                                .disabled(isUpdatingReminder)
                        }
                    }

                    Divider()
                    HStack(alignment: .top) {
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
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        ReminderDateTimePicker(selection: $reminderDate, component: .time,
                            repeatMode: reminderRepeat, weekday: reminderWeekday,
                            onEditingChanged: { isEditingReminderDateTime = $0 })
                            .disabled(isUpdatingReminder)
                    }
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
            }
            if !reminderEnabled {
                Text(reminderPreviewText).font(.caption).foregroundStyle(.secondary)
            }
            Text(L10n.string("Notifications are used only for reminders."))
                .font(.caption).foregroundStyle(.secondary)
        }
        .disabled(!hasLoadedSettings)
        .onAppear {
            if !hasLoadedSettings || !hasReminderChanges {
                loadStoredSettings()
            }
            Task {
                await migrateReminderSettingsIfNeeded()
                hasLoadedSettings = true
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
        .onChange(of: isEditingReminderDateTime) {
            scheduleReminderUpdate()
        }
        .onChange(of: reminderRepeat) { _, newValue in
            if newValue == .none, nextReminderDate == nil {
                reminderDate = defaultOneTimeReminderDate
            }
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
        let settings = StoredReminderSettings.load()
        reminderEnabled = settings.isEnabled
        reminderDate = UserDefaults.standard.object(forKey: AppPreferenceKey.reminderDate) == nil
            ? Date(timeIntervalSinceReferenceDate: reminderDateTimeInterval) : settings.date
        reminderRepeat = settings.repeatMode
        reminderWeekday = validWeekday(settings.weekday)
    }

    private func saveReminderSettings() async {
        guard hasReminderChanges, canSaveReminder, !isUpdatingReminder, !isEditingReminderDateTime else {
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
            try await ReminderService.updateReminder(isEnabled: reminderEnabled,
                date: reminderDate, repeatMode: reminderRepeat, weekday: reminderWeekday)
            loadStoredSettings()
            notificationAuthorizationStatus = await ReminderService.authorizationStatus()
        } catch {
            notificationAuthorizationStatus = await ReminderService.authorizationStatus()
            errorMessage = .error(error)
        }
    }

    private func scheduleReminderUpdate() {
        reminderUpdateTask?.cancel()
        reminderUpdateTask = nil

        guard hasLoadedSettings, !isEditingReminderDateTime else {
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
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        var draft = ReminderDateTimeDraft(date: reminderDate)
        draft.day = tomorrow
        return draft.resolvedDate() ?? tomorrow
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
        let hadChanges = hasReminderChanges
        do {
            try await ReminderService.migrateSettingsIfNeeded(defaultDate: reminderDate)
            if !hadChanges && !isUpdatingReminder { loadStoredSettings() }
        } catch {
            errorMessage = .error(error)
        }
    }
}
