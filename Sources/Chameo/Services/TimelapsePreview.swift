import AppKit
import Photos

/// Bounded, local-only previews must not start iCloud downloads before export.
enum TimelapsePreview {
    static func thumbnail(for asset: ChameoAsset) async -> NSImage? {
        let manager = PHImageManager.default()
        let state = TimelapseImageRequestState()
        do {
            let image = try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    guard state.install(continuation) else { return }
                    let options = PHImageRequestOptions()
                    options.deliveryMode = .highQualityFormat
                    options.resizeMode = .fast
                    options.isNetworkAccessAllowed = false
                    let id = manager.requestImage(for: asset.asset,
                        targetSize: CGSize(width: 360, height: 360), contentMode: .aspectFill,
                        options: options) { image, info in
                            if (info?[PHImageResultIsDegradedKey] as? Bool) == true { return }
                            if let image = image?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                                state.resume(returning: image)
                            } else {
                                state.resume(throwing: CancellationError())
                            }
                        }
                    state.setRequestID(id, imageManager: manager)
                }
            } onCancel: { state.cancel(imageManager: manager) }
            return NSImage(cgImage: image, size: .zero)
        } catch { return nil }
    }
}
