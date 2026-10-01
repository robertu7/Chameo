import Foundation

struct CapturePhotoSaveResult<Asset> {
    let asset: Asset
    let localCopyFailed: Bool
}

@MainActor
enum CapturePhotoSaveService {
    /// Photos is the commit boundary. A subsequent local failure must not cause
    /// capture retries to create a second Photos asset.
    static func save<Asset>(
        data: Data,
        saveToPhotos: (Data) async throws -> Asset,
        saveLocally: (Data, Asset) async throws -> Void
    ) async throws -> CapturePhotoSaveResult<Asset> {
        let asset = try await saveToPhotos(data)
        do {
            try await saveLocally(data, asset)
            return CapturePhotoSaveResult(asset: asset, localCopyFailed: false)
        } catch {
            return CapturePhotoSaveResult(asset: asset, localCopyFailed: true)
        }
    }
}
