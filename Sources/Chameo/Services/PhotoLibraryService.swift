import AppKit
import CoreLocation
import Foundation
import Photos

enum PhotoLibraryService {
    private static let albumCoordinator = PhotoAlbumCoordinator()

    static func authorizationStatus() -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    static func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    static func ensureAuthorized() async throws {
        switch authorizationStatus() {
        case .authorized, .limited:
            return
        case .notDetermined:
            let status = await requestAuthorization()
            guard status == .authorized || status == .limited else {
                throw PhotoLibraryError.notAuthorized
            }
        case .denied, .restricted:
            throw PhotoLibraryError.notAuthorized
        @unknown default:
            throw PhotoLibraryError.notAuthorized
        }
    }

    static func fetchAlbum(named albumName: String) -> PHAssetCollection? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", albumName)
        return PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options).firstObject
    }

    static func fetchAlbumNames() async throws -> [String] {
        try await ensureAuthorized()

        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
        var names: [String] = []

        collections.enumerateObjects { collection, _, _ in
            guard let title = collection.localizedTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !title.isEmpty else {
                return
            }

            names.append(title)
        }

        return Array(Set(names)).sorted { lhs, rhs in
            lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }

    static func createAlbum(named albumName: String) async throws -> PHAssetCollection {
        try await ensureAuthorized()
        return try await albumCoordinator.album(named: normalizedAlbumName(albumName))
    }

    static func ensureAlbum(named albumName: String) async throws -> PHAssetCollection {
        try await albumCoordinator.album(named: normalizedAlbumName(albumName))
    }

    static func savePhoto(data: Data, albumName: String, location: CLLocation? = nil) async throws -> ChameoAsset {
        try await ensureAuthorized()
        let album = try await ensureAlbum(named: normalizedAlbumName(albumName))
        let temporaryURL = try writeTemporaryJPEG(data)

        defer {
            try? FileManager.default.removeItem(at: temporaryURL)
        }

        var assetPlaceholder: PHObjectPlaceholder?
        try await PHPhotoLibrary.shared().performChanges {
            guard let albumRequest = PHAssetCollectionChangeRequest(for: album) else {
                return
            }

            let assetRequest = PHAssetCreationRequest.forAsset()
            assetRequest.creationDate = Date()
            assetRequest.location = location
            assetRequest.addResource(with: .photo, fileURL: temporaryURL, options: nil)

            guard let placeholder = assetRequest.placeholderForCreatedAsset else {
                return
            }

            assetPlaceholder = placeholder
            albumRequest.addAssets([placeholder] as NSArray)
        }

        guard let localIdentifier = assetPlaceholder?.localIdentifier,
              let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject else {
            throw PhotoLibraryError.assetCreationFailed
        }

        return ChameoAsset(asset: asset)
    }

    static func fetchAssets(albumName: String) async throws -> [ChameoAsset] {
        try await ensureAuthorized()
        guard let album = fetchAlbum(named: normalizedAlbumName(albumName)) else {
            return []
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(in: album, options: options)

        var assets: [ChameoAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(ChameoAsset(asset: asset))
        }
        return assets
    }

    static func deleteAsset(_ asset: PHAsset) async throws {
        try await ensureAuthorized()
        try await performPhotoLibraryChanges {
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        }
    }

    static func thumbnail(for asset: PHAsset, size: CGSize) async -> NSImage? {
        await withCheckedContinuation { continuation in
            let lock = NSLock()
            var didResume = false

            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true

            PHCachingImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                lock.lock()
                defer { lock.unlock() }

                guard !didResume else {
                    return
                }

                didResume = true
                continuation.resume(returning: image)
            }
        }
    }

    static func normalizedAlbumName(_ albumName: String) -> String {
        let trimmed = albumName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Chameo" : trimmed
    }

    private static func writeTemporaryJPEG(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Chameo-\(UUID().uuidString)")
            .appendingPathExtension("jpg")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func performPhotoLibraryChanges(_ changes: @escaping () -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let completion = PhotoLibraryChangeCompletion(continuation)

            PHPhotoLibrary.shared().performChanges(changes) { success, error in
                if let error {
                    completion.resume(throwing: error)
                } else if success {
                    completion.resume()
                } else {
                    completion.resume(throwing: PhotoLibraryError.changeFailed)
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
                completion.resume(throwing: PhotoLibraryError.changeTimedOut)
            }
        }
    }
}

private actor PhotoAlbumCoordinator {
    func album(named name: String) async throws -> PHAssetCollection {
        if let existingAlbum = PhotoLibraryService.fetchAlbum(named: name) {
            return existingAlbum
        }

        var albumPlaceholder: PHObjectPlaceholder?
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(
                withTitle: name
            )
            albumPlaceholder = request.placeholderForCreatedAssetCollection
        }

        guard let localIdentifier = albumPlaceholder?.localIdentifier,
              let album = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [localIdentifier],
                options: nil
              ).firstObject else {
            throw PhotoLibraryError.albumCreationFailed
        }

        return album
    }
}

private final class PhotoLibraryChangeCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?

    init(_ continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func resume() {
        resume { continuation in
            continuation.resume()
        }
    }

    func resume(throwing error: Error) {
        resume { continuation in
            continuation.resume(throwing: error)
        }
    }

    private func resume(_ action: (CheckedContinuation<Void, Error>) -> Void) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()

        if let continuation {
            action(continuation)
        }
    }
}

enum PhotoLibraryError: LocalizedError {
    case notAuthorized
    case albumCreationFailed
    case assetCreationFailed
    case changeFailed
    case changeTimedOut

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Allow Photos access to save and manage Chameos."
        case .albumCreationFailed:
            return "Could not create the album in Photos."
        case .assetCreationFailed:
            return "The photo was saved but could not be found in Photos."
        case .changeFailed:
            return "Could not delete the photo from Photos."
        case .changeTimedOut:
            return "Deleting the photo took too long. Try again."
        }
    }
}
