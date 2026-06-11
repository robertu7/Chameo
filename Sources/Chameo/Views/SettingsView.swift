import CoreLocation
import Photos
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @AppStorage("albumName") private var albumName = "Chameo"
    @AppStorage("showGrid") private var showFaceGuide = true
    @AppStorage("saveLocation") private var saveLocation = false
    @AppStorage("launchAtLogin") private var storedLaunchAtLogin = false
    @AppStorage("reminderEnabled") private var reminderEnabledStorage = false
    @AppStorage("reminderDate") private var reminderDateTimeInterval = Date().timeIntervalSinceReferenceDate
    @AppStorage("reminderRepeat") private var reminderRepeatRawValue = ReminderRepeat.none.rawValue
    @AppStorage("reminderWeekday") private var reminderWeekdayStorage = Calendar.current.component(.weekday, from: Date())
    @AppStorage("reminderSettingsMigrated") private var reminderSettingsMigrated = false

    @State private var launchAtLogin = false
    @State private var reminderEnabled = false
    @State private var reminderDate = Date()
    @State private var reminderRepeat = ReminderRepeat.none
    @State private var reminderWeekday = Calendar.current.component(.weekday, from: Date())
    @State private var isUpdatingLaunchAtLogin = false
    @State private var isUpdatingReminder = false
    @State private var showsReminderProgress = false
    @State private var reminderProgressTask: Task<Void, Never>?
    @State private var isLoadingSettings = true
    @State private var errorMessage: String?
    @State private var photosAuthorizationStatus = PhotoLibraryService.authorizationStatus()
    @State private var locationAuthorizationStatus = CLLocationManager().authorizationStatus
    @State private var notificationAuthorizationStatus = UNAuthorizationStatus.notDetermined

    var body: some View {
        TabView {
            Form {
                Section("Album") {
                    TextField("Album Name", text: $albumName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            albumName = PhotoLibraryService.normalizedAlbumName(albumName)
                        }

                    if isPhotosPermissionDenied {
                        PermissionStatusInline(
                            message: "Photos permission is required to save and show Chameos.",
                            destination: .photos
                        )
                    }
                }

                Section("Camera") {
                    Toggle("Show Face Guide", isOn: $showFaceGuide)
                }

                Section("Location") {
                    Toggle("Save Photo Location", isOn: $saveLocation)

                    if saveLocation && isLocationPermissionDenied {
                        PermissionStatusInline(
                            message: "Location permission is off. Photos will save without location.",
                            destination: .location
                        )
                    }
                }

                Section("Startup") {
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .disabled(isUpdatingLaunchAtLogin)
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            Form {
                Section("Reminder") {
                    Toggle("Enable Reminder", isOn: $reminderEnabled)
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
                        Button("Save Reminder") {
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
                        message: "Notification permission is required to schedule reminders.",
                        destination: .notifications
                    )
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Reminder", systemImage: "bell")
            }
        }
        .frame(width: 460, height: 360)
        .scenePadding()
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
            isLoadingSettings = true
            launchAtLogin = LaunchAtLoginService.isEnabled
            storedLaunchAtLogin = launchAtLogin
            reminderEnabled = reminderEnabledStorage
            reminderDate = Date(timeIntervalSinceReferenceDate: reminderDateTimeInterval)
            reminderRepeat = ReminderRepeat(rawValue: reminderRepeatRawValue) ?? .none
            reminderWeekday = reminderWeekdayStorage
            isLoadingSettings = false

            Task {
                await migrateReminderSettingsIfNeeded()
                await refreshPermissionStatuses()
            }
        }
        .onChange(of: launchAtLogin) { _, newValue in
            guard !isLoadingSettings else {
                return
            }
            guard newValue != LaunchAtLoginService.isEnabled else {
                return
            }

            Task {
                await updateLaunchAtLogin(newValue)
            }
        }
        .onChange(of: reminderEnabled) { _, newValue in
            guard newValue, reminderRepeat == .none, nextReminderDate == nil else {
                return
            }

            reminderDate = defaultOneTimeReminderDate
        }
    }

    private func updateLaunchAtLogin(_ isEnabled: Bool) async {
        errorMessage = nil
        isUpdatingLaunchAtLogin = true

        do {
            try LaunchAtLoginService.setEnabled(isEnabled)
            if isEnabled && LaunchAtLoginService.requiresApproval {
                errorMessage = "Allow Chameo in System Settings > General > Login Items."
            }
            launchAtLogin = LaunchAtLoginService.isEnabled
            storedLaunchAtLogin = launchAtLogin
        } catch {
            launchAtLogin = LaunchAtLoginService.isEnabled
            storedLaunchAtLogin = launchAtLogin
            errorMessage = error.localizedDescription
        }

        isUpdatingLaunchAtLogin = false
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
                let dateToSchedule = normalizedReminderDate
                try await ReminderService.configureReminder(
                    date: dateToSchedule,
                    repeatMode: reminderRepeat,
                    weekday: reminderWeekday
                )
                reminderDate = dateToSchedule
            } else {
                ReminderService.cancelReminder()
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
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                showsReminderProgress = true
            }
        }
    }

    private var hasReminderChanges: Bool {
        reminderEnabled != reminderEnabledStorage
            || abs(reminderDate.timeIntervalSinceReferenceDate - reminderDateTimeInterval) > 1
            || reminderRepeat.rawValue != reminderRepeatRawValue
            || reminderWeekday != reminderWeekdayStorage
    }

    private var canSaveReminder: Bool {
        !reminderEnabled || reminderRepeat != .none || nextReminderDate != nil
    }

    private var normalizedReminderDate: Date {
        guard reminderRepeat == .daily, let nextReminderDate else {
            return reminderDate
        }

        return nextReminderDate
    }

    private var defaultOneTimeReminderDate: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }

    private var reminderPreviewText: String {
        guard reminderEnabled else {
            return "Reminder is off."
        }

        guard let nextReminderDate else {
            return "Selected time has passed."
        }

        return "Next reminder: \(DateFormatters.reminderPreview.string(from: nextReminderDate))"
    }

    private var nextReminderDate: Date? {
        let calendar = Calendar.current
        let now = Date()

        switch reminderRepeat {
        case .none:
            return reminderDate > now ? reminderDate : nil
        case .daily:
            var components = calendar.dateComponents([.hour, .minute], from: reminderDate)
            components.second = 0

            guard let today = calendar.nextDate(
                after: now,
                matching: components,
                matchingPolicy: .nextTime,
                direction: .forward
            ) else {
                return nil
            }

            return today
        case .weekly:
            var components = calendar.dateComponents([.hour, .minute], from: reminderDate)
            components.weekday = reminderWeekday
            components.second = 0

            return calendar.nextDate(
                after: now,
                matching: components,
                matchingPolicy: .nextTime,
                direction: .forward
            )
        }
    }

    private func weekdayName(for weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        guard symbols.indices.contains(weekday - 1) else {
            return ""
        }

        return symbols[weekday - 1]
    }

    private var isPhotosPermissionDenied: Bool {
        switch photosAuthorizationStatus {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    private var isLocationPermissionDenied: Bool {
        switch locationAuthorizationStatus {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    private var isNotificationPermissionDenied: Bool {
        switch notificationAuthorizationStatus {
        case .denied:
            return true
        default:
            return false
        }
    }

    private func refreshPermissionStatuses() async {
        photosAuthorizationStatus = PhotoLibraryService.authorizationStatus()
        locationAuthorizationStatus = CLLocationManager().authorizationStatus
        notificationAuthorizationStatus = await ReminderService.authorizationStatus()
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
