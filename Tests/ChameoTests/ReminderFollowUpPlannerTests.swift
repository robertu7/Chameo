import XCTest
import UserNotifications
@testable import Chameo

final class ReminderNotificationPlannerTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testDailyReminderSchedulesHourlyFollowUpsThroughEndOfDay() throws {
        let reminder = try date(2026, 6, 18, 9, 30)
        let now = try date(2026, 6, 18, 9, 0)

        let notifications = ReminderNotificationPlanner.notifications(
            reminderDate: reminder,
            repeatMode: .daily,
            weekday: nil,
            now: now,
            completedAt: nil,
            hourlyFollowUpsEnabled: true,
            limit: 20,
            calendar: calendar
        )

        XCTAssertEqual(notifications.first?.date, try date(2026, 6, 18, 9, 30))
        XCTAssertEqual(notifications.first?.kind, .primary)
        XCTAssertEqual(notifications[1].date, try date(2026, 6, 18, 10, 30))
        XCTAssertEqual(notifications[1].kind, .followUp)
        XCTAssertEqual(notifications[14].date, try date(2026, 6, 18, 23, 30))
        XCTAssertEqual(notifications[15].date, try date(2026, 6, 19, 9, 30))
        XCTAssertEqual(notifications[15].kind, .primary)
    }

    func testCompletedDayIsSkipped() throws {
        let notifications = ReminderNotificationPlanner.notifications(
            reminderDate: try date(2026, 6, 18, 18, 0),
            repeatMode: .daily,
            weekday: nil,
            now: try date(2026, 6, 18, 12, 0),
            completedAt: try date(2026, 6, 18, 11, 0),
            hourlyFollowUpsEnabled: true,
            limit: 10,
            calendar: calendar
        )

        let completedDay = try date(2026, 6, 18, 0, 0)
        XCTAssertEqual(notifications.first?.date, try date(2026, 6, 19, 18, 0))
        XCTAssertEqual(notifications.first?.kind, .primary)
        XCTAssertFalse(notifications.contains { calendar.isDate($0.date, inSameDayAs: completedDay) })
    }

    func testFollowUpsDoNotCrossMidnight() throws {
        let notifications = ReminderNotificationPlanner.notifications(
            reminderDate: try date(2026, 6, 18, 23, 30),
            repeatMode: .none,
            weekday: nil,
            now: try date(2026, 6, 18, 12, 0),
            completedAt: nil,
            hourlyFollowUpsEnabled: true,
            limit: 10,
            calendar: calendar
        )

        XCTAssertEqual(notifications.map(\.kind), [.primary])
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
            await notifications.schedule("today-follow-up")
        }

        try await Task.sleep(nanoseconds: 5_000_000)

        async let second: Void = queue.perform {
            await notifications.remove("today-follow-up")
        }

        _ = try await (first, second)
        let pendingIdentifiers = await notifications.identifiers
        XCTAssertFalse(pendingIdentifiers.contains("today-follow-up"))
    }
}

final class ReminderSelfieCompletionTests: XCTestCase {
    private static let reminderDefaultKeys = [
        "lastSelfieDate",
        "reminderEnabled",
        "reminderDate",
        "reminderRepeat",
        "reminderWeekday",
        "hourlyReminderFollowUpsEnabled"
    ]

    func testRecordingSelfieRemovesTodayPendingAndDeliveredReminderNotifications() async throws {
        let restoreDefaults = preserveReminderDefaults()
        defer { restoreDefaults() }

        let context = try configureReminderDefaults(completedAt: nil)
        let unrelatedPending = "unrelated.pending"
        let unrelatedDelivered = "unrelated.delivered"
        let center = ReminderNotificationCenterRecorder(
            pending: [context.todayPrimary, context.todayFollowUp, unrelatedPending],
            delivered: [context.todayPrimary, context.todayFollowUp, ReminderService.requestIdentifier, unrelatedDelivered]
        )

        await ReminderService.recordSelfieTaken(at: context.now, center: center)

        let pendingIdentifiers = await center.pendingIdentifiers
        XCTAssertFalse(pendingIdentifiers.contains(context.todayPrimary))
        XCTAssertFalse(pendingIdentifiers.contains(context.todayFollowUp))
        XCTAssertTrue(pendingIdentifiers.contains(context.tomorrowPrimary))
        XCTAssertTrue(pendingIdentifiers.contains(unrelatedPending))

        let deliveredIdentifiers = await center.deliveredIdentifiers
        XCTAssertFalse(deliveredIdentifiers.contains(context.todayPrimary))
        XCTAssertFalse(deliveredIdentifiers.contains(context.todayFollowUp))
        XCTAssertFalse(deliveredIdentifiers.contains(ReminderService.requestIdentifier))
        XCTAssertTrue(deliveredIdentifiers.contains(unrelatedDelivered))
    }

    func testLaunchRefreshRemovesDeliveredReminderNotificationsWhenTodayIsAlreadyCompleted() async throws {
        let restoreDefaults = preserveReminderDefaults()
        defer { restoreDefaults() }

        let context = try configureReminderDefaults(completedAt: try date(2026, 6, 23, 10, 21))
        let unrelatedDelivered = "unrelated.delivered"
        let center = ReminderNotificationCenterRecorder(
            pending: [context.todayPrimary, context.todayFollowUp],
            delivered: [context.todayPrimary, context.todayFollowUp, ReminderService.requestIdentifier, unrelatedDelivered]
        )

        await ReminderService.refreshFollowUpsFromStoredSettings(now: context.now, center: center)

        let pendingIdentifiers = await center.pendingIdentifiers
        XCTAssertFalse(pendingIdentifiers.contains(context.todayPrimary))
        XCTAssertFalse(pendingIdentifiers.contains(context.todayFollowUp))
        XCTAssertTrue(pendingIdentifiers.contains(context.tomorrowPrimary))

        let deliveredIdentifiers = await center.deliveredIdentifiers
        XCTAssertFalse(deliveredIdentifiers.contains(context.todayPrimary))
        XCTAssertFalse(deliveredIdentifiers.contains(context.todayFollowUp))
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
            pending: [context.todayPrimary, context.todayFollowUp, unrelatedPending],
            delivered: [context.todayPrimary, ReminderService.requestIdentifier, unrelatedDelivered]
        )

        await ReminderService.refreshFollowUpsFromStoredSettings(now: context.now, center: center)

        let pendingIdentifiers = await center.pendingIdentifiers
        XCTAssertFalse(pendingIdentifiers.contains(context.todayPrimary))
        XCTAssertFalse(pendingIdentifiers.contains(context.todayFollowUp))
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
        todayFollowUp: String,
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
        defaults.set(true, forKey: "hourlyReminderFollowUpsEnabled")

        return (
            now: now,
            todayPrimary: ReminderService.primaryIdentifierPrefix + "20260623-1330",
            todayFollowUp: ReminderService.followUpIdentifierPrefix + "20260623-1430",
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

    init(pending: [String] = [], delivered: [String] = []) {
        self.pending = Set(pending)
        self.delivered = Set(delivered)
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
        pending.subtract(identifiers)
    }

    func removeDeliveredReminderNotifications(withIdentifiers identifiers: [String]) async {
        delivered.subtract(identifiers)
    }
}
