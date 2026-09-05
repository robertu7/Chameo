import Foundation
import OSLog

/// Only Sparkle replacement quits clear reminders; ordinary quits leave them scheduled.
@MainActor
final class UpdateReminderBarrier {
    private(set) var requiresCleanup = false
    private let cleanup: () async throws -> Void
    private let restore: () async -> Void
    private let timeout: Duration
    private var isPreparing = false
    private let logger = Logger(subsystem: AppDistribution.current.bundleIdentifier, category: "reminder-update")

    init(
        timeout: Duration = .seconds(10),
        cleanup: @escaping () async throws -> Void = ReminderService.prepareForApplicationUpdate,
        restore: @escaping () async -> Void = ReminderService.resumeAfterApplicationUpdateCancellation
    ) {
        self.timeout = timeout
        self.cleanup = cleanup
        self.restore = restore
    }

    func updateWillInstall() {
        requiresCleanup = true
    }

    func cancelUpdate() async {
        requiresCleanup = false
        // An in-flight preparation owns rollback, after its cleanup finishes.
        if !isPreparing { await restore() }
    }

    func prepareForTermination() async -> Bool {
        guard !isPreparing else { return false }
        guard requiresCleanup else { return true }
        isPreparing = true
        logger.notice("Preparing reminders before update termination")
        // UserNotifications completion handlers have no deadline. Refuse the quit
        // on timeout, but let the serialized operation finish and roll itself back.
        return await withCheckedContinuation { continuation in
            let reply = TerminationReply(continuation)
            let deadline = Task {
                do { try await Task.sleep(for: timeout) } catch { return }
                logger.error("Reminder cleanup deadline exceeded; refusing update termination")
                reply.finish(false)
            }
            Task {
                var cleaned = false
                do {
                    try await cleanup()
                    cleaned = true
                } catch {
                    // Refuse replacement when the old identity still owns reminders.
                }
                let mayTerminate = cleaned && requiresCleanup && !reply.isFinished
                if !mayTerminate {
                    logger.notice("Resuming reminders after interrupted update preparation")
                    await restore()
                } else {
                    logger.notice("Reminder cleanup verified; allowing update termination")
                }
                isPreparing = false
                deadline.cancel()
                reply.finish(mayTerminate)
            }
        }
    }
}

@MainActor
private final class TerminationReply {
    private var continuation: CheckedContinuation<Bool, Never>?
    var isFinished: Bool { continuation == nil }

    init(_ continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
    }

    func finish(_ allowed: Bool) {
        continuation?.resume(returning: allowed)
        continuation = nil
    }
}
