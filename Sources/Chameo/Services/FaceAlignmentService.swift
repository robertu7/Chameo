import AppKit
import CoreImage
import Foundation
import Vision

struct FaceAlignmentResult {
    let data: Data
    let didAlign: Bool
    let message: String?
}

enum FaceAlignmentService {
    static func alignmentResult(from data: Data) async -> FaceAlignmentResult {
        do {
            return try await Task.detached(priority: .userInitiated) {
                try align(data)
            }.value
        } catch let error as FaceAlignmentError {
            return FaceAlignmentResult(data: data, didAlign: false, message: error.localizedDescription)
        } catch {
            return FaceAlignmentResult(data: data, didAlign: false, message: FaceAlignmentError.processingFailed.localizedDescription)
        }
    }

    private static func align(_ data: Data) throws -> FaceAlignmentResult {
        guard let image = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
            throw FaceAlignmentError.invalidImage
        }

        let extent = image.extent.integral
        guard extent.width > 0, extent.height > 0 else {
            throw FaceAlignmentError.invalidImage
        }

        let context = CIContext(options: [.cacheIntermediates: false])
        guard let detectionImage = context.createCGImage(image, from: extent) else {
            throw FaceAlignmentError.invalidImage
        }

        let face = try largestFace(in: detectionImage)
        guard let landmarks = face.landmarks,
              let leftEye = center(of: landmarks.leftEye, in: face.boundingBox, imageSize: extent.size),
              let rightEye = center(of: landmarks.rightEye, in: face.boundingBox, imageSize: extent.size),
              let nose = center(of: landmarks.nose, in: face.boundingBox, imageSize: extent.size),
              let mouth = center(of: landmarks.outerLips, in: face.boundingBox, imageSize: extent.size) else {
            throw FaceAlignmentError.missingLandmarks
        }

        let input = FaceAlignmentGeometry.Input(
            imageSize: extent.size,
            leftEye: leftEye,
            rightEye: rightEye,
            nose: nose,
            mouth: mouth
        )
        let plan = try FaceAlignmentGeometry.plan(for: input)
        let outputRect = CGRect(origin: .zero, size: plan.outputSize)

        let transformed = image
            .transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
            .clampedToExtent()
            .transformed(by: plan.transform)
            .cropped(to: outputRect)

        guard let outputData = jpegData(from: transformed, rect: outputRect, context: context) else {
            throw FaceAlignmentError.processingFailed
        }

        return FaceAlignmentResult(data: outputData, didAlign: true, message: nil)
    }

    private static func largestFace(in image: CGImage) throws -> VNFaceObservation {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let face = request.results?.max(by: { lhs, rhs in
            lhs.boundingBox.width * lhs.boundingBox.height < rhs.boundingBox.width * rhs.boundingBox.height
        }) else {
            throw FaceAlignmentError.noFace
        }

        return face
    }

    private static func center(
        of region: VNFaceLandmarkRegion2D?,
        in boundingBox: CGRect,
        imageSize: CGSize
    ) -> CGPoint? {
        guard let region, region.pointCount > 0 else {
            return nil
        }

        let points = region.normalizedPoints
        let sum = points.reduce(CGPoint.zero) { partial, point in
            CGPoint(x: partial.x + CGFloat(point.x), y: partial.y + CGFloat(point.y))
        }
        let average = CGPoint(
            x: sum.x / CGFloat(region.pointCount),
            y: sum.y / CGFloat(region.pointCount)
        )

        return CGPoint(
            x: (boundingBox.minX + average.x * boundingBox.width) * imageSize.width,
            y: (boundingBox.minY + average.y * boundingBox.height) * imageSize.height
        )
    }

    private static func jpegData(from image: CIImage, rect: CGRect, context: CIContext) -> Data? {
        guard let cgImage = context.createCGImage(image, from: rect) else {
            return nil
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.92])
    }
}

enum FaceAlignmentError: LocalizedError {
    case invalidImage
    case noFace
    case missingLandmarks
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not read the photo for alignment. You can save the original."
        case .noFace:
            return "Could not detect a face for alignment. You can save the original."
        case .missingLandmarks:
            return "Could not find facial landmarks. You can save the original."
        case .processingFailed:
            return "Could not align the photo. You can save the original."
        }
    }
}

enum FaceAlignmentGeometry {
    struct Input {
        let imageSize: CGSize
        let leftEye: CGPoint
        let rightEye: CGPoint
        let nose: CGPoint
        let mouth: CGPoint
    }

    struct Plan {
        let outputSize: CGSize
        let transform: CGAffineTransform
        let rotationRadians: CGFloat
        let scale: CGFloat
        let anchor: CGPoint
        let targetAnchor: CGPoint
    }

    static let outputLength: CGFloat = 1200
    static let targetEyeDistanceRatio: CGFloat = 0.20
    static let targetAnchor = CGPoint(x: outputLength * 0.5, y: outputLength * 0.48)

    static func plan(for input: Input) throws -> Plan {
        guard input.imageSize.width > 0, input.imageSize.height > 0 else {
            throw FaceAlignmentGeometryError.invalidImageSize
        }

        let eyeVector = CGPoint(
            x: input.rightEye.x - input.leftEye.x,
            y: input.rightEye.y - input.leftEye.y
        )
        let eyeDistance = hypot(eyeVector.x, eyeVector.y)
        guard eyeDistance > 0 else {
            throw FaceAlignmentGeometryError.invalidLandmarks
        }

        let rotation = -atan2(eyeVector.y, eyeVector.x)
        let scale = (outputLength * targetEyeDistanceRatio) / eyeDistance
        let anchor = CGPoint(
            x: (input.leftEye.x + input.rightEye.x + input.nose.x + input.mouth.x) / 4,
            y: (input.leftEye.y + input.rightEye.y + input.nose.y + input.mouth.y) / 4
        )

        let transform = CGAffineTransform.identity
            .translatedBy(x: targetAnchor.x, y: targetAnchor.y)
            .scaledBy(x: scale, y: scale)
            .rotated(by: rotation)
            .translatedBy(x: -anchor.x, y: -anchor.y)

        return Plan(
            outputSize: CGSize(width: outputLength, height: outputLength),
            transform: transform,
            rotationRadians: rotation,
            scale: scale,
            anchor: anchor,
            targetAnchor: targetAnchor
        )
    }
}

enum FaceAlignmentGeometryError: Error {
    case invalidImageSize
    case invalidLandmarks
}
