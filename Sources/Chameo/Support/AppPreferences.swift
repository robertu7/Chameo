import Foundation

enum AppPreferenceKey {
    static let acceptedFaceCaptureQualityScores = "acceptedFaceCaptureQualityScores"
    static let albumName = "albumName"
    static let autoAlignPhotos = "autoAlignPhotos"
    static let handsFreeCountdown = "handsFreeCountdown"
    static let hasCompletedPermissionOnboarding = "hasCompletedPermissionOnboarding"
    static let lastSelfieDate = "lastSelfieDate"
    static let launchAtLogin = "launchAtLogin"
    static let language = "language"
    static let reminderDate = "reminderDate"
    static let reminderEnabled = "reminderEnabled"
    static let reminderRepeat = "reminderRepeat"
    static let reminderSettingsMigrated = "reminderSettingsMigrated"
    static let reminderWeekday = "reminderWeekday"
    static let saveLocation = "saveLocation"
    static let showFaceGuide = "showGrid"
}

struct StoredReminderSettings {
    let isEnabled: Bool
    let date: Date
    let repeatMode: ReminderRepeat
    let weekday: Int
    let lastSelfieDate: Date?

    static func load(from defaults: UserDefaults = .standard) -> StoredReminderSettings {
        let lastSelfieInterval = defaults.object(forKey: AppPreferenceKey.lastSelfieDate) as? Double

        return StoredReminderSettings(
            isEnabled: defaults.bool(forKey: AppPreferenceKey.reminderEnabled),
            date: Date(
                timeIntervalSinceReferenceDate: defaults.double(forKey: AppPreferenceKey.reminderDate)
            ),
            repeatMode: ReminderRepeat(
                rawValue: defaults.string(forKey: AppPreferenceKey.reminderRepeat) ?? ""
            ) ?? .none,
            weekday: defaults.integer(forKey: AppPreferenceKey.reminderWeekday),
            lastSelfieDate: lastSelfieInterval.map(Date.init(timeIntervalSinceReferenceDate:))
        )
    }
}

/// UserDefaults operations are thread-safe; the reminder queue orders multi-key commits.
struct ReminderPreferences: @unchecked Sendable {
    static let standard = ReminderPreferences(defaults: .standard)
    let defaults: UserDefaults

    func load() -> StoredReminderSettings { .load(from: defaults) }
    var hasMigrated: Bool { defaults.bool(forKey: AppPreferenceKey.reminderSettingsMigrated) }
    func markMigrated() { defaults.set(true, forKey: AppPreferenceKey.reminderSettingsMigrated) }

    func save(isEnabled: Bool, date: Date, repeatMode: ReminderRepeat, weekday: Int) {
        defaults.set(date.timeIntervalSinceReferenceDate, forKey: AppPreferenceKey.reminderDate)
        defaults.set(repeatMode.rawValue, forKey: AppPreferenceKey.reminderRepeat)
        defaults.set(weekday, forKey: AppPreferenceKey.reminderWeekday)
        defaults.set(isEnabled, forKey: AppPreferenceKey.reminderEnabled)
    }
}
