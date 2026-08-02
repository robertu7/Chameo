import ChameoCore
import SwiftUI

struct MobileSettingsView: View {
    @Bindable var model: MobileAppModel
    @AppStorage("albumName") private var albumName = "Chameo"
    @AppStorage("showGrid") private var showFaceGuide = true
    @AppStorage("handsFreeCountdown") private var handsFreeCountdown = false
    @AppStorage("autoAlignPhotos") private var autoAlignPhotos = true
    @AppStorage("saveLocation") private var saveLocation = false
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderRepeat") private var reminderRepeatRaw = ReminderRepeat.daily.rawValue
    @AppStorage("reminderDate") private var reminderDateInterval = Date()
        .addingTimeInterval(86_400).timeIntervalSinceReferenceDate
    @AppStorage("reminderWeekday") private var reminderWeekday = Calendar.current.component(
        .weekday,
        from: Date()
    )
    @State private var reminderError: String?

    var body: some View {
        Form {
            Section("Capture") {
                Toggle("Show Face Guide", isOn: $showFaceGuide)
                Toggle("Hands-Free Countdown", isOn: $handsFreeCountdown)
                Toggle("Automatically Align Photos", isOn: $autoAlignPhotos)
                Toggle("Add Location to Photos", isOn: $saveLocation)
            }

            Section("Photos") {
                TextField("Album name", text: $albumName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }

            Section("Reminders") {
                Toggle("Enable Reminders", isOn: $reminderEnabled)
                if reminderEnabled {
                    Picker("Frequency", selection: $reminderRepeatRaw) {
                        Text("Daily").tag(ReminderRepeat.daily.rawValue)
                        Text("Weekly").tag(ReminderRepeat.weekly.rawValue)
                        Text("Once").tag(ReminderRepeat.none.rawValue)
                    }
                    DatePicker(
                        "Time",
                        selection: reminderDateBinding,
                        displayedComponents: reminderRepeatRaw == ReminderRepeat.none.rawValue
                            ? [.date, .hourAndMinute] : [.hourAndMinute]
                    )
                    if reminderRepeatRaw == ReminderRepeat.weekly.rawValue {
                        Picker("Day", selection: $reminderWeekday) {
                            ForEach(1...7, id: \.self) { weekday in
                                Text(Calendar.current.weekdaySymbols[weekday - 1]).tag(weekday)
                            }
                        }
                    }
                }
                if let reminderError {
                    Text(reminderError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section("Language") {
                Picker("Language", selection: languageBinding) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(languageTitle(language)).tag(language)
                    }
                }
            }

            Section("About") {
                LabeledContent("Version", value: versionDescription)
            }
        }
        .navigationTitle("Settings")
        .onChange(of: reminderEnabled) {
            Task {
                let succeeded = await MobileReminderService.setEnabled(reminderEnabled)
                if reminderEnabled && !succeeded {
                    reminderEnabled = false
                    reminderError = String(localized: "Allow Notifications in Settings to schedule reminders.")
                } else {
                    reminderError = nil
                }
            }
        }
        .onChange(of: reminderRepeatRaw) { reconcileReminders() }
        .onChange(of: reminderDateInterval) { reconcileReminders() }
        .onChange(of: reminderWeekday) { reconcileReminders() }
        .onChange(of: saveLocation) {
            if saveLocation { model.locationService.requestAuthorizationIfNeeded() }
        }
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { model.language },
            set: { language in model.selectLanguage(language) }
        )
    }

    private func languageTitle(_ language: AppLanguage) -> String {
        switch language {
        case .automatic: String(localized: "language.automatic")
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        }
    }

    private var versionDescription: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }

    private var reminderDateBinding: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSinceReferenceDate: reminderDateInterval) },
            set: { reminderDateInterval = $0.timeIntervalSinceReferenceDate }
        )
    }

    private func reconcileReminders() {
        guard reminderEnabled else { return }
        Task { await MobileReminderService.reconcileFromDefaults() }
    }
}
