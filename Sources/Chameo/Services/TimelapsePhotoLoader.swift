import CoreImage
import Foundation
@preconcurrency import Photos

struct PhotoOriginalData: Sendable {
    let data: Data
    let fileExtension: String?
    let source: LocalPhotoSnapshot
}

protocol TimelapsePhotoSource: Sendable {
    func snapshot(for identifier: String) throws -> LocalPhotoSnapshot
    func original(for identifier: String, onDownload: @escaping @Sendable (Double) async -> Void) async throws -> PhotoOriginalData
    func currentImage(for identifier: String, onDownload: @escaping @Sendable (Double) async -> Void) async throws -> CGImage
}

struct PhotosTimelapsePhotoSource: TimelapsePhotoSource {
    func snapshot(for identifier: String) throws -> LocalPhotoSnapshot {
        LocalPhotoSnapshot(asset: try asset(for: identifier))
    }

    func original(for identifier: String, onDownload: @escaping @Sendable (Double) async -> Void) async throws -> PhotoOriginalData {
        let asset = try asset(for: identifier)
        let source = LocalPhotoSnapshot(asset: asset)
        guard let resource = PHAssetResource.assetResources(for: asset).first(where: { $0.type == .photo }) else {
            throw TimelapseError.imageUnavailable
        }
        let state = PhotoOriginalRequestState()
        let manager = PHAssetResourceManager.default()
        let data = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard state.install(continuation) else { return }
                let options = PHAssetResourceRequestOptions()
                options.isNetworkAccessAllowed = true
                options.progressHandler = { fraction in
                    guard fraction.isFinite, state.shouldReportProgress() else { return }
                    Task { await onDownload(fraction) }
                }
                let id = manager.requestData(for: resource, options: options,
                                             dataReceivedHandler: { state.append($0) },
                                             completionHandler: { state.finish(error: $0) })
                state.setRequestID(id, manager: manager)
            }
        } onCancel: {
            state.cancel(manager: manager)
        }
        try Task.checkCancellation()
        return PhotoOriginalData(data: data, fileExtension: URL(fileURLWithPath: resource.originalFilename).pathExtension,
                                 source: source)
    }

    func currentImage(for identifier: String, onDownload: @escaping @Sendable (Double) async -> Void) async throws -> CGImage {
        try await TimelapseService.image(for: asset(for: identifier), onDownload: onDownload)
    }

    private func asset(for identifier: String) throws -> PHAsset {
        let status = PhotoLibraryService.authorizationStatus()
        guard status == .authorized || status == .limited else { throw PhotoLibraryError.notAuthorized }
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else {
            throw TimelapseError.imageUnavailable
        }
        return asset
    }
}

/// One resolver per export keeps warning counts separate. Actor work never runs on
/// the main actor, and only one original/frame is retained at a time by the writer.
actor TimelapsePhotoLoader {
    private let store: LocalPhotoStore
    private let source: any TimelapsePhotoSource
    private var failedCopies: Set<String> = []
    private let context = CIContext(options: [.cacheIntermediates: false])

    init(store: LocalPhotoStore = .shared, source: any TimelapsePhotoSource = PhotosTimelapsePhotoSource()) {
        self.store = store
        self.source = source
    }

    var failureCount: Int { failedCopies.count }

    func image(for identifier: String, onDownload: @escaping @Sendable (Double) async -> Void) async throws -> CGImage {
        try Task.checkCancellation()
        guard await store.settings().isEnabled else {
            return try await source.currentImage(for: identifier, onDownload: onDownload)
        }
        let snapshot = try source.snapshot(for: identifier)
        let stored: StoredLocalPhoto?
        let previouslySaved: Bool
        do {
            stored = try await store.original(for: snapshot)
            previouslySaved = try await store.hasSavedOriginal(for: identifier)
            if stored == nil && !previouslySaved {
                try await store.validateDestination()
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            failedCopies.insert(identifier)
            return try await source.currentImage(for: identifier, onDownload: onDownload)
        }

        if stored == nil && previouslySaved {
            // A previously saved copy was removed or renamed by the user.
            return try await source.currentImage(for: identifier, onDownload: onDownload)
        }

        if let stored {
            do {
                if stored.canRender(snapshot) {
                    let image = try decode(stored.data)
                    try Task.checkCancellation()
                    // Detect an edit made while reading/decoding the local file.
                    if stored.canRender(try source.snapshot(for: identifier)) { return image }
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch { failedCopies.insert(identifier) }
            // Preserved originals must never stand in for later Photos edits.
            return try await source.currentImage(for: identifier, onDownload: onDownload)
        }

        do {
            // Reserve the second half for the current Photos rendition if required.
            let original = try await source.original(for: identifier) { fraction in
                await onDownload(min(1, max(0, fraction)) * 0.5)
            }
            try Task.checkCancellation()
            let current = try source.snapshot(for: identifier)
            let isCurrent = original.source.matchesCurrentOriginal(current)
            do {
                try await store.saveOriginal(original.data, source: original.source,
                                             fileExtension: original.fileExtension,
                                             representsCurrentOriginal: isCurrent)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failedCopies.insert(identifier)
            }
            if isCurrent {
                let image = try decode(original.data)
                try Task.checkCancellation()
                await onDownload(1)
                return image
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            failedCopies.insert(identifier)
        }
        try Task.checkCancellation()
        return try await source.currentImage(for: identifier) { fraction in
            await onDownload(0.5 + min(1, max(0, fraction)) * 0.5)
        }
    }

    private func decode(_ data: Data) throws -> CGImage {
        guard let image = CIImage(data: data, options: [.applyOrientationProperty: true]),
              image.extent.width > 0, image.extent.height > 0,
              let decoded = context.createCGImage(image, from: image.extent) else {
            throw LocalPhotoError.invalidImage
        }
        return decoded
    }
}
