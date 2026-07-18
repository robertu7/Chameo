import Foundation

enum AppPreferenceKey {
    static let albumName = "albumName"
    static let autoAlignPhotos = "autoAlignPhotos"
    static let lastSelfieDate = "lastSelfieDate"
    static let launchAtLogin = "launchAtLogin"
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
