import AppKit
import CoreLocation
import Foundation
import Photos

enum PhotoLibraryService {
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

    static func ensureAlbum(named albumName: String) async throws -> PHAssetCollection {
        if let existingAlbum = fetchAlbum(named: albumName) {
            return existingAlbum
        }

        var albumPlaceholder: PHObjectPlaceholder?
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
            albumPlaceholder = request.placeholderForCreatedAssetCollection
        }

        guard let localIdentifier = albumPlaceholder?.localIdentifier else {
            throw PhotoLibraryError.albumCreationFailed
        }

        let result = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let album = result.firstObject else {
            throw PhotoLibraryError.albumCreationFailed
        }

        return album
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
            let assetRequest = PHAssetCreationRequest.forAsset()
            assetRequest.creationDate = Date()
            assetRequest.location = location
            assetRequest.addResource(with: .photo, fileURL: temporaryURL, options: nil)

            guard let placeholder = assetRequest.placeholderForCreatedAsset,
                  let albumRequest = PHAssetCollectionChangeRequest(for: album) else {
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

    static func removeAssetFromAlbum(_ asset: PHAsset, albumName: String) async throws {
        try await ensureAuthorized()
        guard let album = fetchAlbum(named: normalizedAlbumName(albumName)) else {
            return
        }

        try await PHPhotoLibrary.shared().performChanges {
            guard let albumRequest = PHAssetCollectionChangeRequest(for: album) else {
                return
            }

            albumRequest.removeAssets([asset] as NSArray)
        }
    }

    static func restoreAssetToAlbum(_ asset: PHAsset, albumName: String) async throws {
        try await ensureAuthorized()
        let album = try await ensureAlbum(named: normalizedAlbumName(albumName))

        try await PHPhotoLibrary.shared().performChanges {
            guard let albumRequest = PHAssetCollectionChangeRequest(for: album) else {
                return
            }

            albumRequest.addAssets([asset] as NSArray)
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
}

enum PhotoLibraryError: LocalizedError {
    case notAuthorized
    case albumCreationFailed
    case assetCreationFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Photos access is required to save and manage selfies."
        case .albumCreationFailed:
            return "The Photos album could not be created."
        case .assetCreationFailed:
            return "The captured photo could not be found after saving."
        }
    }
}
