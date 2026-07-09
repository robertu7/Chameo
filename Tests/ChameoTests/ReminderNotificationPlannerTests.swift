import XCTest
import UserNotifications
@testable import Chameo

final class ReminderNotificationPlannerTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testDailyReminderSchedulesPrimaryReminders() throws {
        let reminder = try date(2026, 6, 18, 9, 30)
        let now = try date(2026, 6, 18, 9, 0)

        let notifications = ReminderNotificationPlanner.notifications(
            reminderDate: reminder,
            repeatMode: .daily,
            weekday: nil,
            now: now,
            completedAt: nil,
            limit: 20,
            calendar: calendar
        )

        XCTAssertEqual(notifications.first?.date, try date(2026, 6, 18, 9, 30))
        XCTAssertEqual(notifications[1].date, try date(2026, 6, 19, 9, 30))
    }

    func testCompletedDayIsSkipped() throws {
        let notifications = ReminderNotificationPlanner.notifications(
            reminderDate: try date(2026, 6, 18, 18, 0),
            repeatMode: .daily,
            weekday: nil,
            now: try date(2026, 6, 18, 12, 0),
            completedAt: try date(2026, 6, 18, 11, 0),
            limit: 10,
            calendar: calendar
        )

        let completedDay = try date(2026, 6, 18, 0, 0)
        XCTAssertEqual(notifications.first?.date, try date(2026, 6, 19, 18, 0))
        XCTAssertFalse(notifications.contains { calendar.isDate($0.date, inSameDayAs: completedDay) })
    }

    func testOneTimeReminderSchedulesOnlyPrimaryNotification() throws {
        let notifications = ReminderNotificationPlanner.notifications(
            reminderDate: try date(2026, 6, 18, 23, 30),
            repeatMode: .none,
            weekday: nil,
            now: try date(2026, 6, 18, 12, 0),
            completedAt: nil,
            limit: 10,
            calendar: calendar
        )

        XCTAssertEqual(notifications.map(\.date), [try date(2026, 6, 18, 23, 30)])
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )))
    }
}

final class ReminderOperationQueueTests: XCTestCase {
    func testSaveReconciliationFinishesAfterOverlappingLaunchRefresh() async throws {
        let queue = ReminderOperationQueue()
        let notifications = NotificationRecorder()

        async let first: Void = queue.perform {
            try await Task.sleep(nanoseconds: 50_000_000)
            await notifications.schedule("stale-reminder")
        }

        try await Task.sleep(nanoseconds: 5_000_000)

        async let second: Void = queue.perform {
            await notifications.remove("stale-reminder")
        }

        _ = try await (first, second)
        let pendingIdentifiers = await notifications.identifiers
        XCTAssertFalse(pendingIdentifiers.contains("stale-reminder"))
    }
}

final class ReminderSelfieCompletionTests: XCTestCase {
    private static let reminderDefaultKeys = [
        "lastSelfieDate",
        "reminderEnabled",
        "reminderDate",
        "reminderRepeat",
        "reminderWeekday"
    ]

    func testRecordingSelfieRemovesTodayPendingAndDeliveredReminderNotifications() async throws {
        let restoreDefaults = preserveReminderDefaults()
        defer { restoreDefaults() }

        let context = try configureReminderDefaults(completedAt: nil)
        let unrelatedPending = "unrelated.pending"
        let unrelatedDelivered = "unrelated.delivered"
        let center = ReminderNotificationCenterRecorder(
            pending: [context.todayPrimary, context.legacyReminder, unrelatedPending],
            delivered: [context.todayPrimary, context.legacyReminder, ReminderService.requestIdentifier, unrelatedDelivered]
        )

        await ReminderService.recordSelfieTaken(at: context.now, center: center)

        let pendingIdentifiers = await center.pendingIdentifiers
        XCTAssertFalse(pendingIdentifiers.contains(context.todayPrimary))
        XCTAssertFalse(pendingIdentifiers.contains(context.legacyReminder))
        XCTAssertTrue(pendingIdentifiers.contains(context.tomorrowPrimary))
        XCTAssertTrue(pendingIdentifiers.contains(unrelatedPending))

        let deliveredIdentifiers = await center.deliveredIdentifiers
        XCTAssertFalse(deliveredIdentifiers.contains(context.todayPrimary))
        XCTAssertFalse(deliveredIdentifiers.contains(context.legacyReminder))
        XCTAssertFalse(deliveredIdentifiers.contains(ReminderService.requestIdentifier))
        XCTAssertTrue(deliveredIdentifiers.contains(unrelatedDelivered))
    }

    func testLaunchRefreshRemovesDeliveredReminderNotificationsWhenTodayIsAlreadyCompleted() async throws {
        let restoreDefaults = preserveReminderDefaults()
        defer { restoreDefaults() }

        let context = try configureReminderDefaults(completedAt: try date(2026, 6, 23, 10, 21))
        let unrelatedDelivered = "unrelated.delivered"
        let center = ReminderNotificationCenterRecorder(
            pending: [context.todayPrimary, context.legacyReminder],
            delivered: [context.todayPrimary, context.legacyReminder, ReminderService.requestIdentifier, unrelatedDelivered]
        )

        await ReminderService.refreshRemindersFromStoredSettings(now: context.now, center: center)

        let pendingIdentifiers = await center.pendingIdentifiers
        XCTAssertFalse(pendingIdentifiers.contains(context.todayPrimary))
        XCTAssertFalse(pendingIdentifiers.contains(context.legacyReminder))
        XCTAssertTrue(pendingIdentifiers.contains(context.tomorrowPrimary))

        let deliveredIdentifiers = await center.deliveredIdentifiers
        XCTAssertFalse(deliveredIdentifiers.contains(context.todayPrimary))
        XCTAssertFalse(deliveredIdentifiers.contains(context.legacyReminder))
        XCTAssertFalse(deliveredIdentifiers.contains(ReminderService.requestIdentifier))
        XCTAssertTrue(deliveredIdentifiers.contains(unrelatedDelivered))
    }

    func testLaunchRefreshRemovesDeliveredNotificationsWhenPendingRemovalTimesOut() async throws {
        let restoreDefaults = preserveReminderDefaults()
        defer { restoreDefaults() }

        let context = try configureReminderDefaults(completedAt: try date(2026, 6, 23, 10, 21))
        let unrelatedDelivered = "unrelated.delivered"
        let center = ReminderNotificationCenterRecorder(
            pending: [context.todayPrimary, context.legacyReminder],
            delivered: [context.todayPrimary, context.legacyReminder, ReminderService.requestIdentifier, unrelatedDelivered],
            keepsPendingRequestsOnRemoval: true
        )

        await ReminderService.refreshRemindersFromStoredSettings(now: context.now, center: center)

        let deliveredIdentifiers = await center.deliveredIdentifiers
        XCTAssertFalse(deliveredIdentifiers.contains(context.todayPrimary))
        XCTAssertFalse(deliveredIdentifiers.contains(context.legacyReminder))
        XCTAssertFalse(deliveredIdentifiers.contains(ReminderService.requestIdentifier))
        XCTAssertTrue(deliveredIdentifiers.contains(unrelatedDelivered))
    }

    func testLaunchRefreshRemovesStaleReminderNotificationsWhenReminderIsDisabled() async throws {
        let restoreDefaults = preserveReminderDefaults()
        defer { restoreDefaults() }

        let context = try configureReminderDefaults(completedAt: nil)
        UserDefaults.standard.set(false, forKey: "reminderEnabled")
        let unrelatedPending = "unrelated.pending"
        let unrelatedDelivered = "unrelated.delivered"
        let center = ReminderNotificationCenterRecorder(
            pending: [context.todayPrimary, context.legacyReminder, unrelatedPending],
            delivered: [context.todayPrimary, ReminderService.requestIdentifier, unrelatedDelivered]
        )

        await ReminderService.refreshRemindersFromStoredSettings(now: context.now, center: center)

        let pendingIdentifiers = await center.pendingIdentifiers
        XCTAssertFalse(pendingIdentifiers.contains(context.todayPrimary))
        XCTAssertFalse(pendingIdentifiers.contains(context.legacyReminder))
        XCTAssertTrue(pendingIdentifiers.contains(unrelatedPending))

        let deliveredIdentifiers = await center.deliveredIdentifiers
        XCTAssertFalse(deliveredIdentifiers.contains(context.todayPrimary))
        XCTAssertFalse(deliveredIdentifiers.contains(ReminderService.requestIdentifier))
        XCTAssertTrue(deliveredIdentifiers.contains(unrelatedDelivered))
    }

    func testReminderNotificationIsSuppressedWhenTodayIsAlreadyCompleted() throws {
        let restoreDefaults = preserveReminderDefaults()
        defer { restoreDefaults() }

        UserDefaults.standard.set(true, forKey: "reminderEnabled")
        let completedAt = try date(2026, 6, 23, 10, 21)
        UserDefaults.standard.set(completedAt.timeIntervalSinceReferenceDate, forKey: "lastSelfieDate")

        XCTAssertFalse(ReminderService.shouldPresentReminderNotification(
            identifier: ReminderService.primaryIdentifierPrefix + "20260623-1330",
            at: try date(2026, 6, 23, 13, 30)
        ))
        XCTAssertTrue(ReminderService.shouldPresentReminderNotification(
            identifier: ReminderService.primaryIdentifierPrefix + "20260624-1330",
            at: try date(2026, 6, 24, 13, 30)
        ))
        XCTAssertTrue(ReminderService.shouldPresentReminderNotification(
            identifier: "unrelated.notification",
            at: try date(2026, 6, 23, 13, 30)
        ))
    }

    func testReminderNotificationIsSuppressedWhenReminderIsDisabled() throws {
        let restoreDefaults = preserveReminderDefaults()
        defer { restoreDefaults() }

        UserDefaults.standard.set(false, forKey: "reminderEnabled")
        UserDefaults.standard.removeObject(forKey: "lastSelfieDate")

        XCTAssertFalse(ReminderService.shouldPresentReminderNotification(
            identifier: ReminderService.primaryIdentifierPrefix + "20260623-1330",
            at: try date(2026, 6, 23, 13, 30)
        ))
        XCTAssertTrue(ReminderService.shouldPresentReminderNotification(
            identifier: "unrelated.notification",
            at: try date(2026, 6, 23, 13, 30)
        ))
    }

    private func preserveReminderDefaults() -> () -> Void {
        let defaults = UserDefaults.standard
        let previousValues = Self.reminderDefaultKeys.reduce(into: [String: Any]()) { values, key in
            values[key] = defaults.object(forKey: key)
        }

        return {
            for key in Self.reminderDefaultKeys {
                if let value = previousValues[key] {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
    }

    private func configureReminderDefaults(completedAt: Date?) throws -> (
        now: Date,
        todayPrimary: String,
        legacyReminder: String,
        tomorrowPrimary: String
    ) {
        let reminder = try date(2026, 6, 23, 13, 30)
        let now = try date(2026, 6, 23, 10, 21)
        let defaults = UserDefaults.standard
        defaults.set(completedAt?.timeIntervalSinceReferenceDate, forKey: "lastSelfieDate")
        defaults.set(true, forKey: "reminderEnabled")
        defaults.set(reminder.timeIntervalSinceReferenceDate, forKey: "reminderDate")
        defaults.set(ReminderRepeat.daily.rawValue, forKey: "reminderRepeat")
        defaults.set(3, forKey: "reminderWeekday")

        return (
            now: now,
            todayPrimary: ReminderService.primaryIdentifierPrefix + "20260623-1330",
            legacyReminder: ReminderService.requestIdentifier + ".followUp.20260623-1430",
            tomorrowPrimary: ReminderService.primaryIdentifierPrefix + "20260624-1330"
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) throws -> Date {
        try XCTUnwrap(Calendar.current.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )))
    }
}

private actor NotificationRecorder {
    private(set) var identifiers: Set<String> = []

    func schedule(_ identifier: String) {
        identifiers.insert(identifier)
    }

    func remove(_ identifier: String) {
        identifiers.remove(identifier)
    }
}

private actor ReminderNotificationCenterRecorder: ReminderNotificationCenter {
    private var pending: Set<String>
    private var delivered: Set<String>
    private let keepsPendingRequestsOnRemoval: Bool

    init(
        pending: [String] = [],
        delivered: [String] = [],
        keepsPendingRequestsOnRemoval: Bool = false
    ) {
        self.pending = Set(pending)
        self.delivered = Set(delivered)
        self.keepsPendingRequestsOnRemoval = keepsPendingRequestsOnRemoval
    }

    var pendingIdentifiers: Set<String> {
        pending
    }

    var deliveredIdentifiers: Set<String> {
        delivered
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        true
    }

    func add(_ request: UNNotificationRequest) async throws {
        pending.insert(request.identifier)
    }

    func pendingReminderNotificationIdentifiers() async -> [String] {
        Array(pending)
    }

    func deliveredReminderNotificationIdentifiers() async -> [String] {
        Array(delivered)
    }

    func removePendingReminderNotifications(withIdentifiers identifiers: [String]) async {
        guard !keepsPendingRequestsOnRemoval else {
            return
        }

        pending.subtract(identifiers)
    }

    func removeDeliveredReminderNotifications(withIdentifiers identifiers: [String]) async {
        delivered.subtract(identifiers)
    }
}
