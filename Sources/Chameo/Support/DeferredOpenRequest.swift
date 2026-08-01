import Foundation

@MainActor
final class DeferredOpenRequest {
    private var handler: (() -> Void)?
    private var isPending = false

    func performOrDefer() {
        guard let handler else {
            isPending = true
            return
        }

        handler()
    }

    func installHandler(_ handler: @escaping () -> Void) {
        self.handler = handler

        guard isPending else {
            return
        }

        isPending = false
        handler()
    }
}
