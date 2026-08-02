import ChameoCore
import Foundation
@preconcurrency import UserNotifications

@MainActor
enum MobileReminderService {
    private static let notificationLimit = 32

    static func setEnabled(_ enabled: Bool) async -> Bool {
        if enabled {
            let granted = try? await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            guard granted == true else { return false }
        }
        UserDefaults.standard.set(enabled, forKey: "reminderEnabled")
        await reconcileFromDefaults()
        return true
    }

    static func reconcileFromDefaults(now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ownedIDs = pending.map(\.identifier).filter {
            $0.hasPrefix(ReminderNotificationIdentifier.request)
        }
        center.removePendingNotificationRequests(withIdentifiers: ownedIDs)

        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "reminderEnabled") else { return }
        let interval = defaults.double(forKey: "reminderDate")
        let reminderDate = interval == 0
            ? Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
            : Date(timeIntervalSinceReferenceDate: interval)
        let repeatMode = ReminderRepeat(
            rawValue: defaults.string(forKey: "reminderRepeat") ?? ""
        ) ?? .daily
        let completedAt = (defaults.object(forKey: "lastSelfieDate") as? Double).map {
            Date(timeIntervalSinceReferenceDate: $0)
        }
        let notifications = ReminderNotificationPlanner.notifications(
            reminderDate: reminderDate,
            repeatMode: repeatMode,
            weekday: defaults.integer(forKey: "reminderWeekday"),
            now: now,
            completedAt: completedAt,
            limit: notificationLimit
        )
        for notification in notifications {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Time for your Chameo")
            content.body = String(localized: "Take today’s photo and keep your timeline up to date.")
            content.sound = nil
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: notification.date
            )
            try? await center.add(
                UNNotificationRequest(
                    identifier: notification.identifier,
                    content: content,
                    trigger: UNCalendarNotificationTrigger(
                        dateMatching: components,
                        repeats: false
                    )
                )
            )
        }
    }

    static func recordChameo(at date: Date = Date()) async {
        UserDefaults.standard.set(
            date.timeIntervalSinceReferenceDate,
            forKey: "lastSelfieDate"
        )
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let todayPending = pending.filter { request in
            request.identifier.hasPrefix(ReminderNotificationIdentifier.primaryPrefix)
                && request.trigger.flatMap {
                    ($0 as? UNCalendarNotificationTrigger)?.nextTriggerDate()
                }.map { Calendar.current.isDate($0, inSameDayAs: date) } == true
        }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: todayPending)
        let delivered = await center.deliveredNotifications()
        let deliveredIDs = delivered.filter {
            $0.request.identifier.hasPrefix(ReminderNotificationIdentifier.request)
        }.map { $0.request.identifier }
        center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
        await reconcileFromDefaults(now: date)
    }
}
