import Foundation

/// AVAssetWriter calls its completion on a private queue. Polling lets the task
/// cancel even when the framework has not yet called that completion.
final class TimelapseWriterCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false

    var isFinished: Bool {
        lock.lock()
        defer { lock.unlock() }
        return finished
    }

    func finish() {
        lock.lock()
        finished = true
        lock.unlock()
    }
}
