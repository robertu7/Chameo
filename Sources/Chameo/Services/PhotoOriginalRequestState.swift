import Foundation
@preconcurrency import Photos

/// PhotoKit may complete before returning its request ID, or call back after
/// cancellation. Every mutable field is protected by the lock.
final class PhotoOriginalRequestState: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Data, Error>?
    private var requestID: PHAssetResourceDataRequestID?
    private var cancelled = false
    private var data = Data()
    private var lastProgress: ContinuousClock.Instant?

    func install(_ continuation: CheckedContinuation<Data, Error>) -> Bool {
        lock.lock()
        guard !cancelled else {
            lock.unlock()
            continuation.resume(throwing: CancellationError())
            return false
        }
        self.continuation = continuation
        lock.unlock()
        return true
    }

    func setRequestID(_ id: PHAssetResourceDataRequestID, manager: PHAssetResourceManager) {
        lock.lock()
        requestID = id
        let shouldCancel = cancelled
        lock.unlock()
        if shouldCancel { manager.cancelDataRequest(id) }
    }

    func append(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        guard continuation != nil, !cancelled else { return }
        data.append(chunk)
    }

    func shouldReportProgress() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard continuation != nil, !cancelled else { return false }
        let now = ContinuousClock.now
        if let lastProgress, now - lastProgress < .milliseconds(100) { return false }
        lastProgress = now
        return true
    }

    func finish(error: Error?) {
        lock.lock()
        let completion = continuation
        let result = data
        continuation = nil
        data = Data()
        lock.unlock()
        if let error { completion?.resume(throwing: error) }
        else { completion?.resume(returning: result) }
    }

    func cancel(manager: PHAssetResourceManager) {
        lock.lock()
        cancelled = true
        let id = requestID
        let completion = continuation
        continuation = nil
        data = Data()
        lock.unlock()
        if let id { manager.cancelDataRequest(id) }
        completion?.resume(throwing: CancellationError())
    }
}
