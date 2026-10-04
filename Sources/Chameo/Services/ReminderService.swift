import Foundation
import OSLog
@preconcurrency import UserNotifications

enum ReminderService {
    static let requestIdentifier = ReminderNotificationIdentifier.request
    static let primaryIdentifierPrefix = ReminderNotificationIdentifier.primaryPrefix
    private static let legacyFollowUpIdentifierPrefix = "\(requestIdentifier).followUp."
    private static let maximumNotificationRequests = 60
    private static let pendingRemovalAttempts = 3
    private static let pendingRemovalChecksPerAttempt = 20
    private static let pendingRemovalCheckDelay = Duration.milliseconds(10)
    private static let selfieDeliveredCleanupAttempts = 3
    private static let selfieDeliveredCleanupDelay = Duration.milliseconds(200)
    private static let wakeDeliveredCleanupAttempts = 4
    private static let wakeDeliveredCleanupDelay = Duration.milliseconds(500)
    private static let operationQueue = ReminderOperationQueue()
    private static let logger = Logger(
        subsystem: AppDistribution.current.bundleIdentifier,
        category: "reminders"
    )

    // Keep the old code identity alive until its reminders are gone. The queue
    // drains earlier work and suppresses refresh/settings work during replacement.
    static func prepareForApplicationUpdate() async throws {
        try await operationQueue.suspend {
            try await clearRemindersForApplicationUpdate(from: SystemReminderNotificationCenter())
        }
    }

    static func resumeAfterApplicationUpdateCancellation() async {
        await operationQueue.resume()
        await refreshRemindersFromStoredSettings()
    }

    static func clearRemindersForApplicationUpdate(
        from center: any ReminderNotificationCenter
    ) async throws {
        for _ in 0..<pendingRemovalAttempts {
            let pending = await center.pendingReminderNotificationIdentifiers().filter(isReminderIdentifier)
            let delivered = await center.deliveredReminderNotificationIdentifiers().filter(isReminderIdentifier)
            await center.removePendingReminderNotifications(withIdentifiers: pending)
            await center.removeDeliveredReminderNotifications(withIdentifiers: delivered)
            try await Task.sleep(for: selfieDeliveredCleanupDelay)
            let remainingPending = await center.pendingReminderNotificationIdentifiers().filter(isReminderIdentifier)
            let remainingDelivered = await center.deliveredReminderNotificationIdentifiers().filter(isReminderIdentifier)
            if remainingPending.isEmpty && remainingDelivered.isEmpty { return }
        }
        throw ReminderError.updateTimedOut
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func migrateSettingsIfNeeded(
        center: any ReminderNotificationCenter = SystemReminderNotificationCenter(),
        preferences: ReminderPreferences = .standard, defaultDate: Date = Date()
    ) async throws {
        try await operationQueue.perform {
            guard !preferences.hasMigrated else { return }
            let settings = preferences.load()
            let date = preferences.defaults.object(forKey: AppPreferenceKey.reminderDate) == nil
                ? defaultDate : settings.date
            let hasScheduledReminder = await center.pendingReminderNotificationIdentifiers()
                .contains(where: isReminderIdentifier)
            preferences.save(isEnabled: hasScheduledReminder, date: date, repeatMode: settings.repeatMode,
                weekday: Calendar.current.component(.weekday, from: date))
            preferences.markMigrated()
        }
    }

    static func updateReminder(
        isEnabled: Bool, date: Date, repeatMode: ReminderRepeat, weekday: Int,
        center: any ReminderNotificationCenter = SystemReminderNotificationCenter(),
        preferences: ReminderPreferences = .standard, now: Date? = nil
    ) async throws {
        try await operationQueue.perform {
            if isEnabled {
                guard try await center.requestAuthorization(options: [.alert, .sound]) else {
                    throw ReminderError.notAuthorized
                }
                try await reconcileNotifications(date: date, repeatMode: repeatMode, weekday: weekday,
                    center: center, now: now ?? Date(), completedAt: preferences.load().lastSelfieDate)
            } else {
                try await removeAllReminderNotifications(from: center)
            }
            // Commit before releasing the queue, so the next refresh sees this schedule.
            preferences.save(isEnabled: isEnabled, date: date, repeatMode: repeatMode, weekday: weekday)
            preferences.markMigrated()
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

        do {
            try await operationQueue.perform {
                let settings = StoredReminderSettings.load()
                guard settings.isEnabled else { return }
                do {
                    try await reconcileNotifications(
                        date: settings.date,
                        repeatMode: settings.repeatMode,
                        weekday: settings.weekday,
                        center: center,
                        now: date
                    )
                } catch {
                    await removeDeliveredReminderNotifications(
                        from: center,
                        maximumAttempts: selfieDeliveredCleanupAttempts,
                        retryDelay: selfieDeliveredCleanupDelay
                    )
                    throw error
                }

                await removeDeliveredReminderNotifications(
                    from: center,
                    maximumAttempts: selfieDeliveredCleanupAttempts,
                    retryDelay: selfieDeliveredCleanupDelay
                )
            }
        } catch {
            logger.error(
                "Failed to reconcile reminders after a saved selfie; delivered cleanup was still attempted: \(error.localizedDescription, privacy: .private)"
            )
        }
    }

    static func refreshRemindersFromStoredSettings(now: Date = Date()) async {
        await refreshRemindersFromStoredSettings(now: now, center: SystemReminderNotificationCenter())
    }

    static func refreshRemindersFromStoredSettings(
        now: Date, center: any ReminderNotificationCenter,
        preferences: ReminderPreferences = .standard
    ) async {
        do {
            try await operationQueue.perform {
                let settings = preferences.load()
                guard settings.isEnabled else {
                    try await removeAllReminderNotifications(from: center)
                    return
                }
                do {
                    try await reconcileNotifications(date: settings.date, repeatMode: settings.repeatMode,
                        weekday: settings.weekday, center: center, now: now,
                        completedAt: settings.lastSelfieDate)
                } catch {
                    logger.error("Failed to reconcile reminders during refresh: \(error.localizedDescription, privacy: .private)")
                }
                if hasSelfieTaken(on: now, settings: settings) {
                    await removeDeliveredReminderNotifications(from: center,
                        maximumAttempts: wakeDeliveredCleanupAttempts)
                }
            }
        } catch {
            logger.error("Failed to refresh reminders: \(error.localizedDescription, privacy: .private)")
            if hasSelfieTaken(on: now, settings: preferences.load()) {
                await removeDeliveredReminderNotifications(from: center,
                    maximumAttempts: wakeDeliveredCleanupAttempts)
            }
        }
    }

    private static func reconcileNotifications(
        date: Date,
        repeatMode: ReminderRepeat,
        weekday: Int?,
        center: any ReminderNotificationCenter,
        now: Date = Date(),
        completedAt: Date? = StoredReminderSettings.load().lastSelfieDate
    ) async throws {
        let notifications = plannedNotifications(
            date: date,
            repeatMode: repeatMode,
            weekday: weekday,
            now: now,
            completedAt: completedAt
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

        let identifiersToRemove = Set(identifiers)

        for _ in 0..<pendingRemovalAttempts {
            await center.removePendingReminderNotifications(withIdentifiers: identifiers)

            for _ in 0..<pendingRemovalChecksPerAttempt {
                let pendingIdentifiers = Set(await center.pendingReminderNotificationIdentifiers())
                if identifiersToRemove.isDisjoint(with: pendingIdentifiers) {
                    return
                }
                try await Task.sleep(for: pendingRemovalCheckDelay)
            }
        }

        throw ReminderError.updateTimedOut
    }

    private static func plannedNotifications(
        date: Date,
        repeatMode: ReminderRepeat,
        weekday: Int?,
        now: Date,
        completedAt: Date?
    ) -> [PlannedReminderNotification] {
        return ReminderNotificationPlanner.notifications(
            reminderDate: date,
            repeatMode: repeatMode,
            weekday: weekday,
            now: now,
            completedAt: completedAt,
            limit: maximumNotificationRequests
        )
    }

    static func hasSelfieTaken(
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
        maximumAttempts: Int = 1,
        retryDelay: Duration = wakeDeliveredCleanupDelay
    ) async {
        var removedReminder = false

        for attempt in 1...max(1, maximumAttempts) {
            let identifiers = await center.deliveredReminderNotificationIdentifiers().filter(isReminderIdentifier)
            if identifiers.isEmpty {
                if removedReminder {
                    return
                }
            } else {
                await center.removeDeliveredReminderNotifications(withIdentifiers: identifiers)
                removedReminder = true
            }

            guard attempt < maximumAttempts else { return }
            do {
                try await Task.sleep(for: retryDelay)
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
