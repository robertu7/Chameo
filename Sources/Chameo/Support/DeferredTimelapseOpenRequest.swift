import Foundation

/// Completion actions can arrive before launch has installed its file handler.
@MainActor
final class DeferredTimelapseOpenRequest {
    private var pendingID: UUID?
    private var handler: ((UUID) -> Void)?

    func performOrDefer(_ id: UUID) {
        guard let handler else { pendingID = id; return }
        handler(id)
    }

    func installHandler(_ handler: @escaping (UUID) -> Void) {
        self.handler = handler
        if let pendingID {
            self.pendingID = nil
            handler(pendingID)
        }
    }
}
