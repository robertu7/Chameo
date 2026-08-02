import ChameoCore
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers
@preconcurrency import Vision

struct MobileFaceAlignmentResult: Sendable {
    let data: Data
    let didAlign: Bool
}

nonisolated enum MobileFaceProcessingService {
    static func qualityEvaluation(from data: Data) async -> FaceCaptureQualityEvaluation {
        await Task.detached(priority: .utility) { quality(data) }.value
    }

    static func alignmentResult(from data: Data) async -> MobileFaceAlignmentResult {
        await Task.detached(priority: .userInitiated) {
            (try? align(data)) ?? MobileFaceAlignmentResult(data: data, didAlign: false)
        }.value
    }

    private static func quality(_ data: Data) -> FaceCaptureQualityEvaluation {
        guard let image = CIImage(data: data, options: [.applyOrientationProperty: true]),
              image.extent.width > 0, image.extent.height > 0 else {
            return .unreadableImage
        }
        let request = VNDetectFaceCaptureQualityRequest()
        request.revision = VNDetectFaceCaptureQualityRequestRevision3
        do {
            try VNImageRequestHandler(ciImage: image).perform([request])
        } catch {
            return .analysisFailed
        }
        return FaceCaptureQualitySelection.evaluation(
            from: (request.results ?? []).map {
                FaceCaptureQualityCandidate(
                    area: $0.boundingBox.width * $0.boundingBox.height,
                    score: $0.faceCaptureQuality
                )
            }
        )
    }

    private static func align(_ data: Data) throws -> MobileFaceAlignmentResult {
        guard let image = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
            throw MobileFaceProcessingError.invalidImage
        }
        let extent = image.extent.integral
        let context = CIContext(options: [.cacheIntermediates: false])
        guard extent.width > 0, extent.height > 0,
              let detectionImage = context.createCGImage(image, from: extent) else {
            throw MobileFaceProcessingError.invalidImage
        }

        let request = VNDetectFaceLandmarksRequest()
        try VNImageRequestHandler(cgImage: detectionImage).perform([request])
        guard let face = (request.results ?? []).max(by: {
            $0.boundingBox.width * $0.boundingBox.height
                < $1.boundingBox.width * $1.boundingBox.height
        }), let landmarks = face.landmarks,
              let leftEye = center(landmarks.leftEye, face: face, size: extent.size),
              let rightEye = center(landmarks.rightEye, face: face, size: extent.size),
              let nose = center(landmarks.nose, face: face, size: extent.size),
              let mouth = center(landmarks.outerLips, face: face, size: extent.size) else {
            throw MobileFaceProcessingError.missingFace
        }
        let plan = try FaceAlignmentGeometry.plan(for: .init(
            imageSize: extent.size,
            leftEye: leftEye,
            rightEye: rightEye,
            nose: nose,
            mouth: mouth
        ))
        let outputRect = CGRect(origin: .zero, size: plan.outputSize)
        let output = image
            .transformed(by: .init(translationX: -extent.minX, y: -extent.minY))
            .clampedToExtent()
            .transformed(by: plan.transform)
            .cropped(to: outputRect)
        guard let cgImage = context.createCGImage(output, from: outputRect) else {
            throw MobileFaceProcessingError.outputFailed
        }
        let mutableData = NSMutableData()
        guard let finalDestination = CGImageDestinationCreateWithData(
            mutableData, UTType.jpeg.identifier as CFString, 1, nil
        ) else { throw MobileFaceProcessingError.outputFailed }
        CGImageDestinationAddImage(
            finalDestination,
            cgImage,
            [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary
        )
        guard CGImageDestinationFinalize(finalDestination) else {
            throw MobileFaceProcessingError.outputFailed
        }
        return MobileFaceAlignmentResult(data: mutableData as Data, didAlign: true)
    }

    private static func center(
        _ region: VNFaceLandmarkRegion2D?,
        face: VNFaceObservation,
        size: CGSize
    ) -> CGPoint? {
        guard let region, region.pointCount > 0 else { return nil }
        let average = region.normalizedPoints.reduce(CGPoint.zero) {
            CGPoint(x: $0.x + CGFloat($1.x), y: $0.y + CGFloat($1.y))
        }
        let point = CGPoint(
            x: average.x / CGFloat(region.pointCount),
            y: average.y / CGFloat(region.pointCount)
        )
        return CGPoint(
            x: (face.boundingBox.minX + point.x * face.boundingBox.width) * size.width,
            y: (face.boundingBox.minY + point.y * face.boundingBox.height) * size.height
        )
    }
}

nonisolated private enum MobileFaceProcessingError: Error {
    case invalidImage
    case missingFace
    case outputFailed
}
