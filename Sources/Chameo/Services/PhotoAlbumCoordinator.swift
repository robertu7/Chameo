import Photos

actor PhotoAlbumCoordinator {
    private let find: (String) -> PHAssetCollection?
    private let create: (String) async throws -> PHAssetCollection
    private var pending: [String: Task<PHAssetCollection, Error>] = [:]

    init(find: @escaping (String) -> PHAssetCollection? = PhotoLibraryService.fetchAlbum,
         create: @escaping (String) async throws -> PHAssetCollection = PhotoAlbumCoordinator.createAlbum) {
        self.find = find
        self.create = create
    }

    func album(named name: String) async throws -> PHAssetCollection {
        if let task = pending[name] { return try await task.value }
        if let existingAlbum = find(name) {
            return existingAlbum
        }

        let task = Task { try await create(name) }
        pending[name] = task
        defer { pending[name] = nil }
        return try await task.value
    }

    private static func createAlbum(named name: String) async throws -> PHAssetCollection {
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
