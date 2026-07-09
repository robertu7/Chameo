import Foundation
import UserNotifications

enum ReminderService {
    static let requestIdentifier = "com.robertu.Chameo.chameoReminder"
    static let primaryIdentifierPrefix = "\(requestIdentifier).primary."
    private static let legacyFollowUpIdentifierPrefix = "\(requestIdentifier).followUp."
    private static let maximumNotificationRequests = 60
    private static let operationQueue = ReminderOperationQueue()

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func hasScheduledReminder() async -> Bool {
        await UNUserNotificationCenter.current()
            .pendingNotificationRequests()
            .contains { isReminderIdentifier($0.identifier) }
    }

    static func configureReminder(
        date: Date,
        repeatMode: ReminderRepeat,
        weekday: Int? = nil
    ) async throws {
        try await operationQueue.perform {
            try await configureReminderNow(
                date: date,
                repeatMode: repeatMode,
                weekday: weekday
            )
        }
    }

    private static func configureReminderNow(
        date: Date,
        repeatMode: ReminderRepeat,
        weekday: Int?
    ) async throws {
        let center = UNUserNotificationCenter.current()

        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        guard granted else {
            throw ReminderError.notAuthorized
        }

        try await reconcileNotifications(
            date: date,
            repeatMode: repeatMode,
            weekday: weekday,
            center: center
        )
    }

    static func cancelReminder() async throws {
        try await operationQueue.perform {
            try await removeAllReminderNotifications(from: UNUserNotificationCenter.current())
        }
    }

    static func recordSelfieTaken(at date: Date = Date()) async {
        await recordSelfieTaken(at: date, center: UNUserNotificationCenter.current())
    }

    static func recordSelfieTaken(
        at date: Date,
        center: any ReminderNotificationCenter
    ) async {
        UserDefaults.standard.set(date.timeIntervalSinceReferenceDate, forKey: "lastSelfieDate")

        guard UserDefaults.standard.bool(forKey: "reminderEnabled") else {
            return
        }

        let storedDate = UserDefaults.standard.double(forKey: "reminderDate")
        let reminderDate = Date(timeIntervalSinceReferenceDate: storedDate)
        let repeatMode = ReminderRepeat(
            rawValue: UserDefaults.standard.string(forKey: "reminderRepeat") ?? ""
        ) ?? .none
        let weekday = UserDefaults.standard.integer(forKey: "reminderWeekday")

        do {
            try await operationQueue.perform {
                try await reconcileNotifications(
                    date: reminderDate,
                    repeatMode: repeatMode,
                    weekday: weekday,
                    center: center,
                    now: date
                )
                await removeDeliveredReminderNotifications(from: center)
            }
        } catch {
            NSLog("Failed to reconcile reminder notifications after selfie completion: \(error.localizedDescription)")
        }
    }

    static func refreshRemindersFromStoredSettings(now: Date = Date()) async {
        await refreshRemindersFromStoredSettings(now: now, center: UNUserNotificationCenter.current())
    }

    static func refreshRemindersFromStoredSettings(
        now: Date,
        center: any ReminderNotificationCenter
    ) async {
        guard UserDefaults.standard.bool(forKey: "reminderEnabled") else {
            do {
                try await operationQueue.perform {
                    try await removeAllReminderNotifications(from: center)
                }
            } catch {
                NSLog("Failed to remove disabled reminder notifications: \(error.localizedDescription)")
            }
            return
        }

        let reminderDate = Date(
            timeIntervalSinceReferenceDate: UserDefaults.standard.double(forKey: "reminderDate")
        )
        let repeatMode = ReminderRepeat(
            rawValue: UserDefaults.standard.string(forKey: "reminderRepeat") ?? ""
        ) ?? .none
        let isCompletedToday = hasSelfieTaken(on: now)

        do {
            try await operationQueue.perform {
                do {
                    try await reconcileNotifications(
                        date: reminderDate,
                        repeatMode: repeatMode,
                        weekday: UserDefaults.standard.integer(forKey: "reminderWeekday"),
                        center: center,
                        now: now
                    )
                } catch {
                    NSLog("Failed to reconcile reminder notifications during refresh: \(error.localizedDescription)")
                }

                if isCompletedToday {
                    await removeDeliveredReminderNotifications(from: center)
                }
            }
        } catch {
            NSLog("Failed to refresh reminder notifications: \(error.localizedDescription)")
            if isCompletedToday {
                await removeDeliveredReminderNotifications(from: center)
            }
        }
    }

    private static func reconcileNotifications(
        date: Date,
        repeatMode: ReminderRepeat,
        weekday: Int?,
        center: any ReminderNotificationCenter,
        now: Date = Date()
    ) async throws {
        let notifications = plannedNotifications(
            date: date,
            repeatMode: repeatMode,
            weekday: weekday,
            now: now
        )
        let desiredIdentifiers = Set(notifications.map(\.identifier))
        let obsoleteIdentifiers = await center.pendingReminderNotificationIdentifiers()
            .filter {
                isReminderIdentifier($0) && !desiredIdentifiers.contains($0)
            }
        try await removePendingRequests(obsoleteIdentifiers, from: center)

        try await schedule(notifications: notifications, center: center)
    }

    private static func removePendingRequests(
        _ identifiers: [String],
        from center: any ReminderNotificationCenter
    ) async throws {
        guard !identifiers.isEmpty else { return }

        await center.removePendingReminderNotifications(withIdentifiers: identifiers)
        let identifiersToRemove = Set(identifiers)

        for _ in 0..<50 {
            let pendingIdentifiers = Set(await center.pendingReminderNotificationIdentifiers())
            if identifiersToRemove.isDisjoint(with: pendingIdentifiers) {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        throw ReminderError.updateTimedOut
    }

    private static func plannedNotifications(
        date: Date,
        repeatMode: ReminderRepeat,
        weekday: Int?,
        now: Date
    ) -> [PlannedReminderNotification] {
        let lastSelfieDate = UserDefaults.standard.object(forKey: "lastSelfieDate") as? Double
        let completedAt = lastSelfieDate.map(Date.init(timeIntervalSinceReferenceDate:))
        return ReminderNotificationPlanner.notifications(
            reminderDate: date,
            repeatMode: repeatMode,
            weekday: weekday,
            now: now,
            completedAt: completedAt,
            limit: maximumNotificationRequests
        )
    }

    private static func hasSelfieTaken(on date: Date) -> Bool {
        guard let lastSelfieDate = UserDefaults.standard.object(forKey: "lastSelfieDate") as? Double else {
            return false
        }

        return Calendar.current.isDate(
            Date(timeIntervalSinceReferenceDate: lastSelfieDate),
            inSameDayAs: date
        )
    }

    private static func schedule(
        notifications: [PlannedReminderNotification],
        center: any ReminderNotificationCenter
    ) async throws {
        for notification in notifications {
            let content = UNMutableNotificationContent()
            content.title = "Take your Chameo"
            content.body = "Capture today's photo for your timeline."
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: notification.date
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try await center.add(
                UNNotificationRequest(identifier: notification.identifier, content: content, trigger: trigger)
            )
        }
    }

    static func removeAllReminderNotifications(from center: any ReminderNotificationCenter) async throws {
        let identifiers = await center.pendingReminderNotificationIdentifiers().filter(isReminderIdentifier)
        try await removePendingRequests(identifiers, from: center)
        await removeDeliveredReminderNotifications(from: center)
    }

    private static func removeDeliveredReminderNotifications(from center: any ReminderNotificationCenter) async {
        let identifiers = await center.deliveredReminderNotificationIdentifiers().filter(isReminderIdentifier)
        guard !identifiers.isEmpty else { return }

        await center.removeDeliveredReminderNotifications(withIdentifiers: identifiers)
    }

    static func isReminderIdentifier(_ identifier: String) -> Bool {
        identifier == requestIdentifier
            || identifier.hasPrefix(primaryIdentifierPrefix)
            || identifier.hasPrefix(legacyFollowUpIdentifierPrefix)
    }

    static func shouldPresentReminderNotification(identifier: String, at date: Date = Date()) -> Bool {
        guard isReminderIdentifier(identifier) else {
            return true
        }

        guard UserDefaults.standard.bool(forKey: "reminderEnabled") else {
            return false
        }

        return !hasSelfieTaken(on: date)
    }
}

protocol ReminderNotificationCenter {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func pendingReminderNotificationIdentifiers() async -> [String]
    func deliveredReminderNotificationIdentifiers() async -> [String]
    func removePendingReminderNotifications(withIdentifiers identifiers: [String]) async
    func removeDeliveredReminderNotifications(withIdentifiers identifiers: [String]) async
}

extension UNUserNotificationCenter: ReminderNotificationCenter {
    func pendingReminderNotificationIdentifiers() async -> [String] {
        await pendingNotificationRequests().map(\.identifier)
    }

    func deliveredReminderNotificationIdentifiers() async -> [String] {
        await deliveredNotifications().map(\.request.identifier)
    }

    func removePendingReminderNotifications(withIdentifiers identifiers: [String]) async {
        removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeDeliveredReminderNotifications(withIdentifiers identifiers: [String]) async {
        removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}

actor ReminderOperationQueue {
    private var tail: Task<Void, Never>?

    func perform(_ operation: @escaping @Sendable () async throws -> Void) async throws {
        let previous = tail
        let operationTask = Task<Result<Void, Error>, Never> {
            await previous?.value
            do {
                try await operation()
                return .success(())
            } catch {
                return .failure(error)
            }
        }
        tail = Task {
            _ = await operationTask.value
        }

        try await operationTask.value.get()
    }
}

struct PlannedReminderNotification: Equatable {
    let identifier: String
    let date: Date
}

enum ReminderNotificationPlanner {
    static func notifications(
        reminderDate: Date,
        repeatMode: ReminderRepeat,
        weekday: Int?,
        now: Date,
        completedAt: Date?,
        limit: Int,
        calendar: Calendar = .current
    ) -> [PlannedReminderNotification] {
        guard limit > 0 else { return [] }

        var result: [PlannedReminderNotification] = []
        var dayOffset = 0
        let today = calendar.startOfDay(for: now)
        let reminderTime = calendar.dateComponents([.hour, .minute], from: reminderDate)

        while result.count < limit && dayOffset < 365 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today),
                  let occurrence = calendar.date(
                    bySettingHour: reminderTime.hour ?? 0,
                    minute: reminderTime.minute ?? 0,
                    second: 0,
                    of: day
                  ) else {
                break
            }

            let isOccurrenceDay: Bool
            switch repeatMode {
            case .none:
                isOccurrenceDay = calendar.isDate(occurrence, inSameDayAs: reminderDate)
            case .daily:
                isOccurrenceDay = true
            case .weekly:
                let reminderWeekday = weekday ?? calendar.component(.weekday, from: reminderDate)
                isOccurrenceDay = calendar.component(.weekday, from: day) == reminderWeekday
            }

            let isCompleted = completedAt.map { calendar.isDate($0, inSameDayAs: day) } ?? false
            if isOccurrenceDay && !isCompleted {
                if occurrence > now {
                    result.append(notification(for: occurrence, calendar: calendar))
                }
            }

            if repeatMode == .none && day >= calendar.startOfDay(for: reminderDate) {
                break
            }
            dayOffset += 1
        }

        return result
    }

    private static func notification(
        for date: Date,
        calendar: Calendar
    ) -> PlannedReminderNotification {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let identifier = ReminderService.primaryIdentifierPrefix
            + String(format: "%04d%02d%02d-%02d%02d", components.year ?? 0, components.month ?? 0,
                     components.day ?? 0, components.hour ?? 0, components.minute ?? 0)
        return PlannedReminderNotification(identifier: identifier, date: date)
    }
}

enum ReminderError: LocalizedError {
    case notAuthorized
    case updateTimedOut

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Notification permission is required to schedule reminders."
        case .updateTimedOut:
            return "The reminder update did not finish. Please try again."
        }
    }
}
