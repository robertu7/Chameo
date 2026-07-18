import Foundation
@preconcurrency import UserNotifications

protocol ReminderNotificationCenter: Sendable {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func pendingReminderNotificationIdentifiers() async -> [String]
    func deliveredReminderNotificationIdentifiers() async -> [String]
    func removePendingReminderNotifications(withIdentifiers identifiers: [String]) async
    func removeDeliveredReminderNotifications(withIdentifiers identifiers: [String]) async
}

// UserNotifications is an Objective-C framework without Sendable annotations.
// This value wrapper exposes only the framework's thread-safe asynchronous API.
struct SystemReminderNotificationCenter: @unchecked Sendable, ReminderNotificationCenter {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func pendingReminderNotificationIdentifiers() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }

    func deliveredReminderNotificationIdentifiers() async -> [String] {
        await center.deliveredNotifications().map(\.request.identifier)
    }

    func removePendingReminderNotifications(withIdentifiers identifiers: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeDeliveredReminderNotifications(withIdentifiers identifiers: [String]) async {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
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
