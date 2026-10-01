import Foundation

@MainActor
enum PhotoDeletionService {
    /// Photos deletion is the commit boundary. A later local failure must not
    /// present the Photos asset as restored or ask the user to delete it again.
    static func delete(
        fromPhotos: () async throws -> Void,
        trashLocalCopy: () async throws -> Void
    ) async throws -> Error? {
        try await fromPhotos()
        do {
            try await trashLocalCopy()
            return nil
        } catch {
            return error
        }
    }
}
