import CoreImage
import Foundation
import Vision

enum FaceCaptureQualityEvaluation: Equatable, Sendable {
    case scored(Float)
    case noFace
    case scoreUnavailable
    case unreadableImage
    case analysisFailed
}

struct FaceCaptureQualityCandidate: Equatable, Sendable {
    let area: CGFloat
    let score: Float?
}

enum FaceCaptureQualitySelection {
    static func evaluation(
        from candidates: [FaceCaptureQualityCandidate]
    ) -> FaceCaptureQualityEvaluation {
        guard let largestFace = candidates.max(by: { $0.area < $1.area }) else {
            return .noFace
        }

        guard let score = largestFace.score else {
            return .scoreUnavailable
        }

        return .scored(score)
    }
}

enum FaceCaptureQualityService {
    static func evaluation(from data: Data) async -> FaceCaptureQualityEvaluation {
        await Task.detached(priority: .utility) {
            analyze(data)
        }.value
    }

    private static func analyze(_ data: Data) -> FaceCaptureQualityEvaluation {
        guard let image = CIImage(
            data: data,
            options: [.applyOrientationProperty: true]
        ), image.extent.width > 0, image.extent.height > 0 else {
            return .unreadableImage
        }

        let request = VNDetectFaceCaptureQualityRequest()
        request.revision = VNDetectFaceCaptureQualityRequestRevision3
        let handler = VNImageRequestHandler(ciImage: image, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return .analysisFailed
        }

        let observations: [VNFaceObservation] = request.results ?? []
        let candidates = observations.map { face in
            FaceCaptureQualityCandidate(
                area: face.boundingBox.width * face.boundingBox.height,
                score: face.faceCaptureQuality
            )
        }
        return FaceCaptureQualitySelection.evaluation(from: candidates)
    }
}
