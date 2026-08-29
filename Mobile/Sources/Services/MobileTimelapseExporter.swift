@preconcurrency import AVFoundation
import CoreImage
import CoreVideo
import Foundation
import Photos

nonisolated enum MobileTimelapseExporter {
    static let outputSize = CGSize(width: 1080, height: 1080)
    static let framesPerSecond: Int32 = 10

    static func encode(
        frames: [Data],
        to outputURL: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        guard !frames.isEmpty else { throw MobileTimelapseError.noFrames }
        let worker = Task.detached(priority: .userInitiated) {
            try? FileManager.default.removeItem(at: outputURL)
            let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
            let input = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: Int(outputSize.width),
                    AVVideoHeightKey: Int(outputSize.height),
                ]
            )
            input.expectsMediaDataInRealTime = false
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: Int(outputSize.width),
                    kCVPixelBufferHeightKey as String: Int(outputSize.height),
                ]
            )
            guard writer.canAdd(input) else { throw MobileTimelapseError.cannotStart }
            writer.add(input)
            guard writer.startWriting() else {
                throw writer.error ?? MobileTimelapseError.cannotStart
            }
            writer.startSession(atSourceTime: .zero)
            let context = CIContext(options: [.cacheIntermediates: false])

            do {
                for (index, data) in frames.enumerated() {
                    try Task.checkCancellation()
                    while !input.isReadyForMoreMediaData {
                        try Task.checkCancellation()
                        try await Task.sleep(for: .milliseconds(10))
                    }
                    guard let pool = adaptor.pixelBufferPool else {
                        throw MobileTimelapseError.cannotCreateFrame
                    }
                    var pixelBuffer: CVPixelBuffer?
                    guard CVPixelBufferPoolCreatePixelBuffer(
                        nil,
                        pool,
                        &pixelBuffer
                    ) == kCVReturnSuccess, let pixelBuffer else {
                        throw MobileTimelapseError.cannotCreateFrame
                    }
                    try render(data: data, into: pixelBuffer, context: context)
                    let presentationTime = CMTime(
                        value: CMTimeValue(index),
                        timescale: framesPerSecond
                    )
                    guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                        throw writer.error ?? MobileTimelapseError.cannotAppendFrame
                    }
                    progress(Double(index + 1) / Double(frames.count))
                }
                input.markAsFinished()
                await writer.finishWriting()
                guard writer.status == .completed else {
                    throw writer.error ?? MobileTimelapseError.cannotFinish
                }
            } catch {
                input.markAsFinished()
                writer.cancelWriting()
                try? FileManager.default.removeItem(at: outputURL)
                throw error
            }
        }

        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    private static func render(
        data: Data,
        into pixelBuffer: CVPixelBuffer,
        context: CIContext
    ) throws {
        guard let image = CIImage(
            data: data,
            options: [.applyOrientationProperty: true]
        ), image.extent.width > 0, image.extent.height > 0 else {
            throw MobileTimelapseError.imageUnavailable
        }
        let target = CGRect(origin: .zero, size: outputSize)
        let scale = max(
            target.width / image.extent.width,
            target.height / image.extent.height
        )
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let translated = scaled.transformed(
            by: CGAffineTransform(
                translationX: target.midX - scaled.extent.midX,
                y: target.midY - scaled.extent.midY
            )
        )
        context.render(
            translated.cropped(to: target),
            to: pixelBuffer,
            bounds: target,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
    }
}

enum MobileTimelapseError: Error {
    case noFrames
    case imageUnavailable
    case cannotStart
    case cannotCreateFrame
    case cannotAppendFrame
    case cannotFinish
}
