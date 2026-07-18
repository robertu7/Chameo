import XCTest
@testable import Chameo

final class AppPreferencesTests: XCTestCase {
    func testStoredReminderSettingsLoadsTypedValues() throws {
        let suiteName = "AppPreferencesTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let reminderDate = Date(timeIntervalSinceReferenceDate: 1_000)
        let completedDate = Date(timeIntervalSinceReferenceDate: 2_000)
        defaults.set(true, forKey: AppPreferenceKey.reminderEnabled)
        defaults.set(
            reminderDate.timeIntervalSinceReferenceDate,
            forKey: AppPreferenceKey.reminderDate
        )
        defaults.set(ReminderRepeat.weekly.rawValue, forKey: AppPreferenceKey.reminderRepeat)
        defaults.set(6, forKey: AppPreferenceKey.reminderWeekday)
        defaults.set(
            completedDate.timeIntervalSinceReferenceDate,
            forKey: AppPreferenceKey.lastSelfieDate
        )

        let settings = StoredReminderSettings.load(from: defaults)

        XCTAssertTrue(settings.isEnabled)
        XCTAssertEqual(settings.date, reminderDate)
        XCTAssertEqual(settings.repeatMode, .weekly)
        XCTAssertEqual(settings.weekday, 6)
        XCTAssertEqual(settings.lastSelfieDate, completedDate)
    }

    func testStoredReminderSettingsFallsBackFromUnknownRepeatValue() throws {
        let suiteName = "AppPreferencesTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set("future-mode", forKey: AppPreferenceKey.reminderRepeat)

        XCTAssertEqual(StoredReminderSettings.load(from: defaults).repeatMode, .none)
    }
}
