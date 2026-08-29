import Foundation

@MainActor
final class DeferredOpenRequest {
    private var handler: ((ReminderNotificationOpenDestination) -> Void)?
    private var pendingDestination: ReminderNotificationOpenDestination?

    func performOrDefer(_ destination: ReminderNotificationOpenDestination) {
        guard let handler else {
            pendingDestination = destination
            return
        }

        handler(destination)
    }

    func installHandler(
        _ handler: @escaping (ReminderNotificationOpenDestination) -> Void
    ) {
        self.handler = handler

        guard let pendingDestination else {
            return
        }

        self.pendingDestination = nil
        handler(pendingDestination)
    }
}
