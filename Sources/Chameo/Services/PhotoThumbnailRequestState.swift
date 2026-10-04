import AppKit
import Photos

/// PhotoKit can call back synchronously, after cancellation, or more than once.
final class PhotoThumbnailRequestState: @unchecked Sendable {
    private let lock = NSLock()
    private let cancelRequest: (PHImageRequestID) -> Void
    private var continuation: CheckedContinuation<NSImage?, Never>?
    private var requestID: PHImageRequestID?
    private var cancelled = false
    private var finished = false

    init(cancelRequest: @escaping (PHImageRequestID) -> Void) { self.cancelRequest = cancelRequest }

    func install(_ continuation: CheckedContinuation<NSImage?, Never>) -> Bool {
        lock.lock()
        guard !cancelled else {
            lock.unlock()
            continuation.resume(returning: nil)
            return false
        }
        self.continuation = continuation
        lock.unlock()
        return true
    }

    func setRequestID(_ id: PHImageRequestID) {
        lock.lock()
        requestID = id
        let shouldCancel = cancelled
        lock.unlock()
        if shouldCancel { cancelRequest(id) }
    }

    func cancel() {
        lock.lock()
        guard !cancelled, !finished else { lock.unlock(); return }
        cancelled = true
        let id = requestID
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        if let id { cancelRequest(id) }
        continuation?.resume(returning: nil)
    }

    func finish(_ image: NSImage?) {
        lock.lock()
        guard !cancelled, !finished else { lock.unlock(); return }
        finished = true
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: image)
    }
}
