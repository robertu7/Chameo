import ChameoCore
import Foundation
import Observation
@preconcurrency import Photos

@MainActor
@Observable
final class MobileTimelapseModel {
    private(set) var isExporting = false
    private(set) var progress = 0.0
    private(set) var outputURL: URL?
    var message: String?

    private var exportTask: Task<Void, Never>?

    func export(assets: [MobileChameoAsset]) {
        guard !isExporting else { return }
        cancel(removeCompletedOutput: true)
        let ordered = TimelapseSelection.datedItemsChronologically(
            from: assets,
            date: { $0.asset.creationDate },
            identifier: \.id
        )
        guard !ordered.isEmpty else {
            message = String(localized: "No Chameos are available for a timelapse.")
            return
        }
        isExporting = true
        progress = 0
        message = nil
        exportTask = Task { [weak self] in
            guard let self else { return }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("Chameo-Timelapse-\(UUID().uuidString).mp4")
            do {
                var frames: [Data] = []
                frames.reserveCapacity(ordered.count)
                for (index, asset) in ordered.enumerated() {
                    try Task.checkCancellation()
                    frames.append(try await MobilePhotoLibraryService.originalData(for: asset))
                    progress = Double(index + 1) / Double(ordered.count) * 0.35
                }
                try await MobileTimelapseExporter.encode(
                    frames: frames,
                    to: url
                ) { [weak self] encodingProgress in
                    Task { @MainActor in
                        self?.progress = 0.35 + encodingProgress * 0.65
                    }
                }
                try Task.checkCancellation()
                outputURL = url
                progress = 1
                message = String(localized: "Timelapse ready")
            } catch is CancellationError {
                try? FileManager.default.removeItem(at: url)
                message = String(localized: "Timelapse export was cancelled.")
            } catch {
                try? FileManager.default.removeItem(at: url)
                message = String(localized: "Every Chameo must be available from iCloud before exporting.")
            }
            isExporting = false
            exportTask = nil
        }
    }

    func cancel(removeCompletedOutput: Bool = false) {
        if let exportTask {
            exportTask.cancel()
        } else {
            isExporting = false
        }
        if removeCompletedOutput, let outputURL {
            try? FileManager.default.removeItem(at: outputURL)
            self.outputURL = nil
        }
    }

    func saveToPhotos() async {
        guard let outputURL else { return }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
            }
            message = String(localized: "Saved timelapse to Photos")
        } catch {
            message = String(localized: "Could not save the timelapse.")
        }
    }

}
