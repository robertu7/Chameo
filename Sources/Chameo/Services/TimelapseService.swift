import AVFoundation
import AppKit
import CoreImage
import Photos

enum TimelapseError: LocalizedError {
    case initializationFailed
    case noAssets
    case imageUnavailable
    case frameCreationFailed
    case writingFailed

    var errorDescription: String? {
        switch self {
        case .initializationFailed:
            return "Could not initialize the video writer."
        case .noAssets:
            return "No photos are available for the timelapse."
        case .imageUnavailable:
            return "A timelapse photo could not be loaded from Photos."
        case .frameCreationFailed:
            return "A video frame could not be created."
        case .writingFailed:
            return "The timelapse video could not be written."
        }
    }
}

enum TimelapseService {
    private static let videoSize = CGSize(width: 1080, height: 1080)
    private static let framesPerSecond: CMTimeScale = 10
    private static let imageContext = CIContext(options: [.cacheIntermediates: false])

    static func generate(assets: [ChameoAsset], to outputURL: URL) async throws {
        guard !assets.isEmpty else {
            throw TimelapseError.noAssets
        }

        let fileManager = FileManager.default
        let replacementDirectory = try fileManager.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: outputURL,
            create: true
        )
        defer {
            try? fileManager.removeItem(at: replacementDirectory)
        }

        let stagedURL = replacementDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        try await write(assets: assets, to: stagedURL)
        try Task.checkCancellation()

        if fileManager.fileExists(atPath: outputURL.path) {
            _ = try fileManager.replaceItemAt(outputURL, withItemAt: stagedURL)
        } else {
            try fileManager.moveItem(at: stagedURL, to: outputURL)
        }
    }

    private static func write(assets: [ChameoAsset], to outputURL: URL) async throws {
        let assetWriter: AVAssetWriter
        do {
            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        } catch {
            throw TimelapseError.initializationFailed
        }

        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(videoSize.width),
            AVVideoHeightKey: Int(videoSize.height)
        ]
        guard assetWriter.canApply(outputSettings: outputSettings, forMediaType: .video) else {
            throw TimelapseError.initializationFailed
        }

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        writerInput.expectsMediaDataInRealTime = false

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: Int(videoSize.width),
            kCVPixelBufferHeightKey as String: Int(videoSize.height),
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )

        guard assetWriter.canAdd(writerInput) else {
            throw TimelapseError.initializationFailed
        }
        assetWriter.add(writerInput)

        guard assetWriter.startWriting() else {
            throw TimelapseError.writingFailed
        }
        assetWriter.startSession(atSourceTime: .zero)

        do {
            for (frameIndex, asset) in assets.enumerated() {
                try Task.checkCancellation()
                let image = try await image(for: asset.asset)
                let pixelBuffer = try makePixelBuffer(
                    for: image,
                    using: pixelBufferAdaptor
                )

                try await waitUntilReady(writerInput, writer: assetWriter)
                let frameTime = CMTime(value: CMTimeValue(frameIndex), timescale: framesPerSecond)
                guard pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: frameTime) else {
                    throw TimelapseError.writingFailed
                }
            }

            writerInput.markAsFinished()
            await withCheckedContinuation { continuation in
                assetWriter.finishWriting {
                    continuation.resume()
                }
            }

            try Task.checkCancellation()
            guard assetWriter.status == .completed else {
                throw TimelapseError.writingFailed
            }
        } catch {
            assetWriter.cancelWriting()
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }
    }

    private static func waitUntilReady(
        _ writerInput: AVAssetWriterInput,
        writer: AVAssetWriter
    ) async throws {
        while !writerInput.isReadyForMoreMediaData {
            try Task.checkCancellation()
            guard writer.status == .writing else {
                throw TimelapseError.writingFailed
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private static func image(for asset: PHAsset) async throws -> CGImage {
        let imageManager = PHImageManager.default()
        let requestState = TimelapseImageRequestState()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard requestState.install(continuation) else {
                    return
                }

                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.resizeMode = .exact
                options.isNetworkAccessAllowed = true

                let requestID = imageManager.requestImage(
                    for: asset,
                    targetSize: videoSize,
                    contentMode: .aspectFill,
                    options: options
                ) { image, info in
                    if let error = info?[PHImageErrorKey] as? Error {
                        requestState.resume(throwing: error)
                        return
                    }
                    if (info?[PHImageCancelledKey] as? Bool) == true {
                        requestState.resume(throwing: CancellationError())
                        return
                    }

                    guard let image else {
                        requestState.resume(throwing: TimelapseError.imageUnavailable)
                        return
                    }

                    var proposedRect = CGRect(origin: .zero, size: image.size)
                    guard let cgImage = image.cgImage(
                        forProposedRect: &proposedRect,
                        context: nil,
                        hints: nil
                    ) else {
                        requestState.resume(throwing: TimelapseError.imageUnavailable)
                        return
                    }

                    requestState.resume(returning: cgImage)
                }
                requestState.setRequestID(requestID, imageManager: imageManager)
            }
        } onCancel: {
            requestState.cancel(imageManager: imageManager)
        }
    }

    private static func makePixelBuffer(
        for image: CGImage,
        using adaptor: AVAssetWriterInputPixelBufferAdaptor
    ) throws -> CVPixelBuffer {
        guard let pool = adaptor.pixelBufferPool else {
            throw TimelapseError.frameCreationFailed
        }

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw TimelapseError.frameCreationFailed
        }

        let imageSize = CGSize(width: image.width, height: image.height)
        let scale = max(videoSize.width / imageSize.width, videoSize.height / imageSize.height)
        let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let cropOrigin = CGPoint(
            x: (scaledSize.width - videoSize.width) / 2,
            y: (scaledSize.height - videoSize.height) / 2
        )
        let renderedImage = CIImage(cgImage: image)
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .cropped(to: CGRect(origin: cropOrigin, size: videoSize))
            .transformed(by: CGAffineTransform(translationX: -cropOrigin.x, y: -cropOrigin.y))

        imageContext.render(
            renderedImage,
            to: pixelBuffer,
            bounds: CGRect(origin: .zero, size: videoSize),
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
        )
        return pixelBuffer
    }
}

private final class TimelapseImageRequestState: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<CGImage, Error>?
    private var requestID: PHImageRequestID?
    private var isCancelled = false

    func install(_ continuation: CheckedContinuation<CGImage, Error>) -> Bool {
        lock.lock()
        if isCancelled {
            lock.unlock()
            continuation.resume(throwing: CancellationError())
            return false
        }
        self.continuation = continuation
        lock.unlock()
        return true
    }

    func setRequestID(_ requestID: PHImageRequestID, imageManager: PHImageManager) {
        lock.lock()
        self.requestID = requestID
        let shouldCancel = isCancelled
        lock.unlock()

        if shouldCancel {
            imageManager.cancelImageRequest(requestID)
        }
    }

    func cancel(imageManager: PHImageManager) {
        lock.lock()
        isCancelled = true
        let requestID = requestID
        let continuation = continuation
        self.continuation = nil
        lock.unlock()

        if let requestID {
            imageManager.cancelImageRequest(requestID)
        }
        continuation?.resume(throwing: CancellationError())
    }

    func resume(returning image: CGImage) {
        resume { continuation in
            continuation.resume(returning: image)
        }
    }

    func resume(throwing error: Error) {
        resume { continuation in
            continuation.resume(throwing: error)
        }
    }

    private func resume(_ action: (CheckedContinuation<CGImage, Error>) -> Void) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()

        if let continuation {
            action(continuation)
        }
    }
}
