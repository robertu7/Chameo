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
        case .authorized:
            return
        case .notDetermined:
            let status = await requestAuthorization()
            guard status == .authorized else {
                throw PhotoLibraryError.notAuthorized
            }
        case .limited, .denied, .restricted:
            throw PhotoLibraryError.notAuthorized
        @unknown default:
            throw PhotoLibraryError.notAuthorized
        }
    }

    static func matchingAlbums(named albumName: String) -> [PHAssetCollection] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", albumName)
        let result = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumRegular,
            options: options
        )
        var collections: [PHAssetCollection] = []
        result.enumerateObjects { collection, _, _ in
            guard collection.localizedTitle == albumName else { return }
            collections.append(collection)
        }
        return collections.sorted { $0.localIdentifier < $1.localIdentifier }
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

    static func savePhoto(
        data: Data,
        albumName: String,
        creationDate: Date = Date(),
        location: CLLocation? = nil
    ) async throws -> ChameoAsset {
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
            assetRequest.creationDate = creationDate
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
        let albums = matchingAlbums(named: normalizedAlbumName(albumName))
        guard !albums.isEmpty else {
            return []
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        var assetsByIdentifier: [String: ChameoAsset] = [:]
        for album in albums {
            let result = PHAsset.fetchAssets(in: album, options: options)
            result.enumerateObjects { asset, _, _ in
                guard ChameoAssetEligibility.isEligible(
                    isPhoto: asset.mediaType == .image,
                    creationDate: asset.creationDate
                ) else {
                    return
                }
                assetsByIdentifier[asset.localIdentifier] = ChameoAsset(asset: asset)
            }
        }
        return assetsByIdentifier.values.sorted { lhs, rhs in
            guard lhs.createdAt != rhs.createdAt else { return lhs.id < rhs.id }
            return (lhs.createdAt ?? .distantPast) > (rhs.createdAt ?? .distantPast)
        }
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
        return trimmed.isEmpty ? AppDistribution.current.defaultAlbumName : trimmed
    }

    fileprivate static func eligibleAssetCount(in album: PHAssetCollection) -> Int {
        let assets = PHAsset.fetchAssets(in: album, options: nil)
        var count = 0
        assets.enumerateObjects { asset, _, _ in
            if ChameoAssetEligibility.isEligible(
                isPhoto: asset.mediaType == .image,
                creationDate: asset.creationDate
            ) {
                count += 1
            }
        }
        return count
    }

    fileprivate static func rememberedAlbumIdentifier(for name: String) -> String? {
        let values = UserDefaults.standard.dictionary(
            forKey: AppPreferenceKey.selectedPhysicalAlbumIdentifiers
        ) as? [String: String]
        return values?[name]
    }

    fileprivate static func rememberAlbumIdentifier(_ identifier: String, for name: String) {
        var values = UserDefaults.standard.dictionary(
            forKey: AppPreferenceKey.selectedPhysicalAlbumIdentifiers
        ) as? [String: String] ?? [:]
        values[name] = identifier
        UserDefaults.standard.set(
            values,
            forKey: AppPreferenceKey.selectedPhysicalAlbumIdentifiers
        )
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
        let existingAlbums = PhotoLibraryService.matchingAlbums(named: name)
        if let existingAlbum = selectAlbum(from: existingAlbums, named: name) {
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

        PhotoLibraryService.rememberAlbumIdentifier(localIdentifier, for: name)
        return album
    }

    private func selectAlbum(
        from albums: [PHAssetCollection],
        named name: String
    ) -> PHAssetCollection? {
        let candidates = albums.map {
            AlbumSelectionCandidate(
                identifier: $0.localIdentifier,
                eligibleChameoCount: PhotoLibraryService.eligibleAssetCount(in: $0)
            )
        }
        guard let identifier = AlbumSelectionPolicy.saveDestination(
            from: candidates,
            rememberedIdentifier: PhotoLibraryService.rememberedAlbumIdentifier(for: name)
        ), let album = albums.first(where: { $0.localIdentifier == identifier }) else {
            return nil
        }
        PhotoLibraryService.rememberAlbumIdentifier(identifier, for: name)
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
            return L10n.string("Allow Photos access to save and manage Chameos.")
        case .albumCreationFailed:
            return L10n.string("Could not create the album in Photos.")
        case .assetCreationFailed:
            return L10n.string("The photo was saved but could not be found in Photos.")
        case .changeFailed:
            return L10n.string("Could not delete the photo from Photos.")
        case .changeTimedOut:
            return L10n.string("Deleting the photo took too long. Try again.")
        }
    }
}
