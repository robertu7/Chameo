import CoreGraphics
import Foundation
import Photos

final class TimelapseImageRequestState: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<CGImage, Error>?
    private var requestID: PHImageRequestID?
    private var isCancelled = false
    private var lastProgressTime: ContinuousClock.Instant?

    func shouldReportProgress() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !isCancelled, continuation != nil else { return false }
        let now = ContinuousClock.now
        if let lastProgressTime, now - lastProgressTime < .milliseconds(100) { return false }
        lastProgressTime = now
        return true
    }

    func install(_ continuation: CheckedContinuation<CGImage, Error>) -> Bool {
        lock.lock()
        if isCancelled {
            lock.unlock()
            continuation.resume(throwing: CancellationError())
            return false
        }
        self.continuation = continuation
        lock.unlock()
        return true
    }

    func setRequestID(_ requestID: PHImageRequestID, imageManager: PHImageManager) {
        lock.lock()
        self.requestID = requestID
        let shouldCancel = isCancelled
        lock.unlock()

        if shouldCancel {
            imageManager.cancelImageRequest(requestID)
        }
    }

    func cancel(imageManager: PHImageManager) {
        lock.lock()
        isCancelled = true
        let requestID = requestID
        let continuation = continuation
        self.continuation = nil
        lock.unlock()

        if let requestID {
            imageManager.cancelImageRequest(requestID)
        }
        continuation?.resume(throwing: CancellationError())
    }

    func resume(returning image: CGImage) {
        resume { continuation in
            continuation.resume(returning: image)
        }
    }

    func resume(throwing error: Error) {
        resume { continuation in
            continuation.resume(throwing: error)
        }
    }

    private func resume(_ action: (CheckedContinuation<CGImage, Error>) -> Void) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()

        if let continuation {
            action(continuation)
        }
    }
}
