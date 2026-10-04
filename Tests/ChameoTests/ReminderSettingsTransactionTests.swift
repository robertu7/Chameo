import UserNotifications
import XCTest
@testable import Chameo

final class ReminderSettingsTransactionTests: XCTestCase {
    func testRefreshQueuedDuringEnableSeesCommittedSettings() async throws {
        try await interleavedRefresh(initiallyEnabled: false, enabled: true)
    }

    func testRefreshQueuedDuringScheduleChangeKeepsNewSchedule() async throws {
        try await interleavedRefresh(initiallyEnabled: true, enabled: true)
    }

    func testAuthorizationDelayUsesCurrentTimeForPlanning() async throws {
        let (defaults, preferences, suite) = isolatedPreferences()
        defer { defaults.removePersistentDomain(forName: suite) }
        let center = TransactionReminderCenter(gateAuthorization: true)
        let date = Date().addingTimeInterval(0.5)
        let update = Task {
            try await ReminderService.updateReminder(isEnabled: true, date: date, repeatMode: .none,
                weekday: 2, center: center, preferences: preferences)
        }
        await center.waitForAuthorization()
        try await Task.sleep(for: .seconds(1))
        await center.authorize()
        try await update.value
        let identifiers = await center.identifiers
        XCTAssertTrue(identifiers.isEmpty, "An elapsed one-time date must not be scheduled using pre-authorization time")
    }

    func testDisablePersistsBeforeRefreshAndDoesNotRequestAuthorization() async throws {
        let (defaults, preferences, suite) = isolatedPreferences()
        defer { defaults.removePersistentDomain(forName: suite) }
        let now = Date()
        preferences.save(isEnabled: true, date: now.addingTimeInterval(3600), repeatMode: .daily, weekday: 2)
        let center = TransactionReminderCenter(gateAuthorization: false)
        try await ReminderService.updateReminder(isEnabled: false, date: now, repeatMode: .daily,
            weekday: 2, center: center, preferences: preferences, now: now)
        await ReminderService.refreshRemindersFromStoredSettings(now: now, center: center, preferences: preferences)
        XCTAssertFalse(preferences.load().isEnabled)
        let authorizationRequests = await center.authorizationRequests
        let identifiers = await center.identifiers
        XCTAssertEqual(authorizationRequests, 0)
        XCTAssertTrue(identifiers.isEmpty)
    }

    func testLegacyMigrationPreservesExistingPendingReminder() async throws {
        let (defaults, preferences, suite) = isolatedPreferences()
        defer { defaults.removePersistentDomain(forName: suite) }
        let date = Date().addingTimeInterval(7200)
        let center = TransactionReminderCenter(gateAuthorization: false)
        await center.add(UNNotificationRequest(identifier: ReminderService.requestIdentifier,
            content: UNMutableNotificationContent(), trigger: nil))
        try await ReminderService.migrateSettingsIfNeeded(center: center, preferences: preferences, defaultDate: date)
        XCTAssertTrue(preferences.hasMigrated)
        XCTAssertTrue(preferences.load().isEnabled)
        XCTAssertEqual(preferences.load().date, date)
        XCTAssertEqual(preferences.load().weekday, Calendar.current.component(.weekday, from: date))
        let authorizationRequests = await center.authorizationRequests
        XCTAssertEqual(authorizationRequests, 0)
    }

    func testLegacyMigrationQueuedAfterSaveCannotReplaceNewSettings() async throws {
        let (defaults, preferences, suite) = isolatedPreferences()
        defer { defaults.removePersistentDomain(forName: suite) }
        let date = Date().addingTimeInterval(7200)
        let center = TransactionReminderCenter(gateAuthorization: true)
        let update = Task {
            try await ReminderService.updateReminder(isEnabled: true, date: date, repeatMode: .weekly,
                weekday: 4, center: center, preferences: preferences)
        }
        await center.waitForAuthorization()
        let migration = Task { try await ReminderService.migrateSettingsIfNeeded(center: center, preferences: preferences) }
        await center.authorize()
        try await update.value
        try await migration.value
        XCTAssertTrue(preferences.hasMigrated)
        XCTAssertTrue(preferences.load().isEnabled)
        XCTAssertEqual(preferences.load().date, date)
        XCTAssertEqual(preferences.load().weekday, 4)
    }

    func testDeniedAuthorizationDoesNotCommitRequestedChanges() async {
        let (defaults, preferences, suite) = isolatedPreferences()
        defer { defaults.removePersistentDomain(forName: suite) }
        let originalDate = Date().addingTimeInterval(3600)
        preferences.save(isEnabled: false, date: originalDate, repeatMode: .weekly, weekday: 3)
        let center = TransactionReminderCenter(gateAuthorization: false, authorized: false)
        do {
            try await ReminderService.updateReminder(isEnabled: true, date: Date(), repeatMode: .daily,
                weekday: 2, center: center, preferences: preferences)
            XCTFail("Expected permission denial")
        } catch { XCTAssertTrue(error is ReminderError) }
        let stored = preferences.load()
        XCTAssertFalse(stored.isEnabled)
        XCTAssertEqual(stored.date, originalDate)
        XCTAssertEqual(stored.repeatMode, .weekly)
        XCTAssertEqual(stored.weekday, 3)
    }

    private func interleavedRefresh(initiallyEnabled: Bool, enabled: Bool) async throws {
        let (defaults, preferences, suite) = isolatedPreferences()
        defer { defaults.removePersistentDomain(forName: suite) }
        let now = Date()
        let oldDate = now.addingTimeInterval(3600)
        let newDate = now.addingTimeInterval(7200)
        preferences.save(isEnabled: initiallyEnabled, date: oldDate, repeatMode: .daily, weekday: 2)
        let center = TransactionReminderCenter(gateAuthorization: true)
        let update = Task {
            try await ReminderService.updateReminder(isEnabled: enabled, date: newDate, repeatMode: .daily,
                weekday: 2, center: center, preferences: preferences, now: now)
        }
        await center.waitForAuthorization()
        let refresh = Task {
            await ReminderService.refreshRemindersFromStoredSettings(now: now, center: center, preferences: preferences)
        }
        // Keep authorization open while activation enters the service; the earlier
        // implementation took its stale preference snapshot during this interval.
        try await Task.sleep(for: .milliseconds(30))
        await center.authorize()
        try await update.value
        await refresh.value
        XCTAssertEqual(preferences.load().date, newDate)
        XCTAssertEqual(preferences.load().isEnabled, enabled)
        let dates = await center.scheduledDates
        XCTAssertFalse(dates.isEmpty)
        let calendar = Calendar.current
        XCTAssertTrue(dates.allSatisfy {
            calendar.component(.hour, from: $0) == calendar.component(.hour, from: newDate)
            && calendar.component(.minute, from: $0) == calendar.component(.minute, from: newDate)
        })
    }

    private func isolatedPreferences() -> (UserDefaults, ReminderPreferences, String) {
        let suite = "ChameoReminderTransactionTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        return (defaults, ReminderPreferences(defaults: defaults), suite)
    }
}

private actor TransactionReminderCenter: ReminderNotificationCenter {
    let gateAuthorization: Bool
    let authorized: Bool
    private var authorization: CheckedContinuation<Bool, Never>?
    var authorizationRequests = 0
    private var requests: [String: UNNotificationRequest] = [:]
    var identifiers: [String] { Array(requests.keys) }
    var scheduledDates: [Date] { requests.values.compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() } }
    init(gateAuthorization: Bool, authorized: Bool = true) {
        self.gateAuthorization = gateAuthorization
        self.authorized = authorized
    }
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationRequests += 1
        if gateAuthorization { return await withCheckedContinuation { authorization = $0 } }
        return authorized
    }
    func waitForAuthorization() async {
        while authorization == nil { await Task.yield() }
    }
    func authorize() { authorization?.resume(returning: authorized); authorization = nil }
    func add(_ request: UNNotificationRequest) { requests[request.identifier] = request }
    func pendingReminderNotificationIdentifiers() -> [String] { identifiers }
    func deliveredReminderNotificationIdentifiers() -> [String] { [] }
    func removePendingReminderNotifications(withIdentifiers identifiers: [String]) {
        identifiers.forEach { requests[$0] = nil }
    }
    func removeDeliveredReminderNotifications(withIdentifiers identifiers: [String]) {}
}
