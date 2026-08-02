import ChameoCore
import CoreLocation
import Foundation
@preconcurrency import Photos
import UIKit

struct MobileChameoAsset: Identifiable, Equatable {
    let id: String
    let asset: PHAsset

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    var createdAt: Date { asset.creationDate! }
    var location: CLLocation? { asset.location }
}

@MainActor
enum MobilePhotoLibraryService {
    static func fetchAssets(albumName: String) async throws -> [MobileChameoAsset] {
        try requireFullAccess()
        let albums = matchingAlbums(named: normalizedName(albumName))
        var assetsByID: [String: MobileChameoAsset] = [:]
        for album in albums {
            let result = PHAsset.fetchAssets(in: album, options: nil)
            result.enumerateObjects { asset, _, _ in
                guard ChameoAssetEligibility.isEligible(
                    isPhoto: asset.mediaType == .image,
                    creationDate: asset.creationDate
                ) else { return }
                assetsByID[asset.localIdentifier] = MobileChameoAsset(
                    id: asset.localIdentifier,
                    asset: asset
                )
            }
        }
        return assetsByID.values.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.id < $1.id
        }
    }

    static func save(
        data: Data,
        albumName: String,
        capturedAt: Date,
        location: CaptureLocation?
    ) async throws -> MobileChameoAsset {
        try requireFullAccess()
        let name = normalizedName(albumName)
        let album = try await destinationAlbum(named: name)
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Chameo-\(UUID().uuidString).jpg")
        try data.write(to: temporaryURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        var placeholder: PHObjectPlaceholder?
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.creationDate = capturedAt
            request.location = location.map(CLLocation.init(captureLocation:))
            request.addResource(with: .photo, fileURL: temporaryURL, options: nil)
            guard let created = request.placeholderForCreatedAsset,
                  let albumRequest = PHAssetCollectionChangeRequest(for: album) else {
                return
            }
            placeholder = created
            albumRequest.addAssets([created] as NSArray)
        }
        guard let id = placeholder?.localIdentifier,
              let asset = PHAsset.fetchAssets(
                withLocalIdentifiers: [id],
                options: nil
              ).firstObject else {
            throw MobilePhotoLibraryError.assetCreationFailed
        }
        return MobileChameoAsset(id: id, asset: asset)
    }

    static func delete(_ asset: MobileChameoAsset) async throws {
        try requireFullAccess()
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets([asset.asset] as NSArray)
        }
    }

    static func thumbnail(for asset: MobileChameoAsset, size: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            PHCachingImageManager.default().requestImage(
                for: asset.asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                guard !isDegraded else { return }
                continuation.resume(returning: image)
            }
        }
    }

    static func originalData(for asset: MobileChameoAsset) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImageDataAndOrientation(
                for: asset.asset,
                options: options
            ) { data, _, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: MobilePhotoLibraryError.imageUnavailable)
                }
            }
        }
    }

    private static func requireFullAccess() throws {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else {
            throw MobilePhotoLibraryError.fullAccessRequired
        }
    }

    private static func matchingAlbums(named name: String) -> [PHAssetCollection] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", name)
        let result = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumRegular,
            options: options
        )
        var albums: [PHAssetCollection] = []
        result.enumerateObjects { album, _, _ in
            guard album.localizedTitle == name else { return }
            albums.append(album)
        }
        return albums
    }

    private static func destinationAlbum(named name: String) async throws -> PHAssetCollection {
        let existing = matchingAlbums(named: name)
        if !existing.isEmpty {
            let remembered = rememberedAlbumIDs()[name]
            let candidates = existing.map {
                AlbumSelectionCandidate(
                    identifier: $0.localIdentifier,
                    eligibleChameoCount: eligibleCount(in: $0)
                )
            }
            if let id = AlbumSelectionPolicy.saveDestination(
                from: candidates,
                rememberedIdentifier: remembered
            ), let album = existing.first(where: { $0.localIdentifier == id }) {
                rememberAlbum(id, for: name)
                return album
            }
        }

        var placeholder: PHObjectPlaceholder?
        try await PHPhotoLibrary.shared().performChanges {
            placeholder = PHAssetCollectionChangeRequest
                .creationRequestForAssetCollection(withTitle: name)
                .placeholderForCreatedAssetCollection
        }
        guard let id = placeholder?.localIdentifier,
              let album = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [id],
                options: nil
              ).firstObject else {
            throw MobilePhotoLibraryError.albumCreationFailed
        }
        rememberAlbum(id, for: name)
        return album
    }

    private static func eligibleCount(in album: PHAssetCollection) -> Int {
        let result = PHAsset.fetchAssets(in: album, options: nil)
        var count = 0
        result.enumerateObjects { asset, _, _ in
            if ChameoAssetEligibility.isEligible(
                isPhoto: asset.mediaType == .image,
                creationDate: asset.creationDate
            ) { count += 1 }
        }
        return count
    }

    private static func rememberedAlbumIDs() -> [String: String] {
        UserDefaults.standard.dictionary(
            forKey: "selectedPhysicalAlbumIdentifiers"
        ) as? [String: String] ?? [:]
    }

    private static func rememberAlbum(_ id: String, for name: String) {
        var values = rememberedAlbumIDs()
        values[name] = id
        UserDefaults.standard.set(values, forKey: "selectedPhysicalAlbumIdentifiers")
    }

    static func normalizedName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Chameo" : trimmed
    }
}

private extension CLLocation {
    convenience init(captureLocation: CaptureLocation) {
        self.init(
            coordinate: CLLocationCoordinate2D(
                latitude: captureLocation.latitude,
                longitude: captureLocation.longitude
            ),
            altitude: captureLocation.altitude,
            horizontalAccuracy: captureLocation.horizontalAccuracy,
            verticalAccuracy: -1,
            timestamp: captureLocation.capturedAt
        )
    }
}

enum MobilePhotoLibraryError: Error {
    case fullAccessRequired
    case albumCreationFailed
    case assetCreationFailed
    case imageUnavailable
}
