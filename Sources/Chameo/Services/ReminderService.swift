import Foundation
import OSLog
@preconcurrency import UserNotifications

enum ReminderService {
    static let requestIdentifier = ReminderNotificationIdentifier.request
    static let primaryIdentifierPrefix = ReminderNotificationIdentifier.primaryPrefix
    private static let legacyFollowUpIdentifierPrefix = "\(requestIdentifier).followUp."
    private static let maximumNotificationRequests = 60
    private static let wakeDeliveredCleanupAttempts = 4
    private static let wakeDeliveredCleanupDelay = Duration.milliseconds(500)
    private static let operationQueue = ReminderOperationQueue()
    private static let logger = Logger(
        subsystem: AppDistribution.current.bundleIdentifier,
        category: "reminders"
    )

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
        let center = SystemReminderNotificationCenter()

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
            try await removeAllReminderNotifications(from: SystemReminderNotificationCenter())
        }
    }

    static func recordSelfieTaken(at date: Date = Date()) async {
        await recordSelfieTaken(at: date, center: SystemReminderNotificationCenter())
    }

    static func recordSelfieTaken(
        at date: Date,
        center: any ReminderNotificationCenter
    ) async {
        UserDefaults.standard.set(
            date.timeIntervalSinceReferenceDate,
            forKey: AppPreferenceKey.lastSelfieDate
        )

        let settings = StoredReminderSettings.load()
        guard settings.isEnabled else {
            return
        }

        do {
            try await operationQueue.perform {
                try await reconcileNotifications(
                    date: settings.date,
                    repeatMode: settings.repeatMode,
                    weekday: settings.weekday,
                    center: center,
                    now: date
                )
                await removeDeliveredReminderNotifications(from: center)
            }
        } catch {
            logger.error(
                "Failed to reconcile reminders after a saved selfie: \(error.localizedDescription, privacy: .private)"
            )
        }
    }

    static func refreshRemindersFromStoredSettings(now: Date = Date()) async {
        await refreshRemindersFromStoredSettings(now: now, center: SystemReminderNotificationCenter())
    }

    static func refreshRemindersFromStoredSettings(
        now: Date,
        center: any ReminderNotificationCenter
    ) async {
        let settings = StoredReminderSettings.load()
        guard settings.isEnabled else {
            do {
                try await operationQueue.perform {
                    try await removeAllReminderNotifications(from: center)
                }
            } catch {
                logger.error(
                    "Failed to remove disabled reminders: \(error.localizedDescription, privacy: .private)"
                )
            }
            return
        }

        let isCompletedToday = hasSelfieTaken(on: now, settings: settings)

        do {
            try await operationQueue.perform {
                do {
                    try await reconcileNotifications(
                        date: settings.date,
                        repeatMode: settings.repeatMode,
                        weekday: settings.weekday,
                        center: center,
                        now: now
                    )
                } catch {
                    logger.error(
                        "Failed to reconcile reminders during refresh: \(error.localizedDescription, privacy: .private)"
                    )
                }

                if isCompletedToday {
                    await removeDeliveredReminderNotifications(
                        from: center,
                        maximumAttempts: wakeDeliveredCleanupAttempts
                    )
                }
            }
        } catch {
            logger.error("Failed to refresh reminders: \(error.localizedDescription, privacy: .private)")
            if isCompletedToday {
                await removeDeliveredReminderNotifications(
                    from: center,
                    maximumAttempts: wakeDeliveredCleanupAttempts
                )
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
            try await Task.sleep(for: .milliseconds(10))
        }

        throw ReminderError.updateTimedOut
    }

    private static func plannedNotifications(
        date: Date,
        repeatMode: ReminderRepeat,
        weekday: Int?,
        now: Date
    ) -> [PlannedReminderNotification] {
        return ReminderNotificationPlanner.notifications(
            reminderDate: date,
            repeatMode: repeatMode,
            weekday: weekday,
            now: now,
            completedAt: StoredReminderSettings.load().lastSelfieDate,
            limit: maximumNotificationRequests
        )
    }

    private static func hasSelfieTaken(
        on date: Date,
        settings: StoredReminderSettings = .load()
    ) -> Bool {
        guard let lastSelfieDate = settings.lastSelfieDate else {
            return false
        }

        return Calendar.current.isDate(lastSelfieDate, inSameDayAs: date)
    }

    private static func schedule(
        notifications: [PlannedReminderNotification],
        center: any ReminderNotificationCenter
    ) async throws {
        for notification in notifications {
            let content = UNMutableNotificationContent()
            let text = reminderNotificationText()
            content.title = text.title
            content.body = text.body
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

    static func reminderNotificationText(
        localization: AppLocalization = L10n.currentLocalization
    ) -> (title: String, body: String) {
        (
            L10n.string("Time for your Chameo", localization: localization),
            L10n.string(
                "Take today’s photo and keep your timeline up to date.",
                localization: localization
            )
        )
    }

    static func removeAllReminderNotifications(from center: any ReminderNotificationCenter) async throws {
        let identifiers = await center.pendingReminderNotificationIdentifiers().filter(isReminderIdentifier)
        try await removePendingRequests(identifiers, from: center)
        await removeDeliveredReminderNotifications(from: center)
    }

    private static func removeDeliveredReminderNotifications(
        from center: any ReminderNotificationCenter,
        maximumAttempts: Int = 1
    ) async {
        for attempt in 1...max(1, maximumAttempts) {
            let identifiers = await center.deliveredReminderNotificationIdentifiers().filter(isReminderIdentifier)
            if !identifiers.isEmpty {
                await center.removeDeliveredReminderNotifications(withIdentifiers: identifiers)
                return
            }

            guard attempt < maximumAttempts else { return }
            do {
                try await Task.sleep(for: wakeDeliveredCleanupDelay)
            } catch {
                return
            }
        }
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

        let settings = StoredReminderSettings.load()
        guard settings.isEnabled else {
            return false
        }

        return !hasSelfieTaken(on: date, settings: settings)
    }
}
