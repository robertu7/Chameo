import CoreGraphics

public enum FaceCaptureQualityEvaluation: Equatable, Sendable {
    case scored(Float)
    case noFace
    case scoreUnavailable
    case unreadableImage
    case analysisFailed
}

public struct FaceCaptureQualityCandidate: Equatable, Sendable {
    public let area: CGFloat
    public let score: Float?

    public init(area: CGFloat, score: Float?) {
        self.area = area
        self.score = score
    }
}

public enum FaceCaptureQualitySelection {
    public static func evaluation(
        from candidates: [FaceCaptureQualityCandidate]
    ) -> FaceCaptureQualityEvaluation {
        guard let largestFace = candidates.max(by: { $0.area < $1.area }) else {
            return .noFace
        }
        guard let score = largestFace.score else { return .scoreUnavailable }
        return .scored(score)
    }
}

public enum CaptureQualitySuggestion: Equatable, Sendable {
    case faceNotDetected
    case retakeRecommended
}

public enum CaptureQualityPolicy {
    public static let minimumBaselineCount = 10
    public static let maximumHistoryCount = 30
    public static let minimumWarningDrop: Float = 0.10

    public static func suggestion(
        for evaluation: FaceCaptureQualityEvaluation,
        acceptedScores: [Float]
    ) -> CaptureQualitySuggestion? {
        switch evaluation {
        case .noFace:
            return .faceNotDetected
        case .scored(let score):
            guard let threshold = warningThreshold(for: acceptedScores),
                  score < threshold else {
                return nil
            }
            return .retakeRecommended
        case .scoreUnavailable, .unreadableImage, .analysisFailed:
            return nil
        }
    }

    public static func warningThreshold(for acceptedScores: [Float]) -> Float? {
        let validScores = acceptedScores
            .filter { (0...1).contains($0) }
            .suffix(maximumHistoryCount)
            .sorted()
        guard validScores.count >= minimumBaselineCount else { return nil }

        let baselineMedian = median(of: validScores)
        let deviations = validScores.map { abs($0 - baselineMedian) }.sorted()
        let medianAbsoluteDeviation = median(of: deviations)
        let meaningfulDrop = max(minimumWarningDrop, 2 * medianAbsoluteDeviation)
        return max(0, baselineMedian - meaningfulDrop)
    }

    private static func median(of sortedValues: [Float]) -> Float {
        let middle = sortedValues.count / 2
        if sortedValues.count.isMultiple(of: 2) {
            return (sortedValues[middle - 1] + sortedValues[middle]) / 2
        }
        return sortedValues[middle]
    }
}
