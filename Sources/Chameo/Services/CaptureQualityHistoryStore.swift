import Foundation

enum CaptureQualitySuggestion: Equatable, Sendable {
    case faceNotDetected
    case retakeRecommended

    var message: String {
        switch self {
        case .faceNotDetected:
            return L10n.string("No face was detected. Place your face inside the guide and retake.")
        case .retakeRecommended:
            return L10n.string("This photo may not match the quality of your recent Chameos.")
        }
    }
}

enum CaptureQualityPolicy {
    static let minimumBaselineCount = 10
    static let maximumHistoryCount = 30
    static let minimumWarningDrop: Float = 0.10

    static func suggestion(
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

    static func warningThreshold(for acceptedScores: [Float]) -> Float? {
        let validScores = acceptedScores
            .filter { (0...1).contains($0) }
            .suffix(maximumHistoryCount)
            .sorted()
        guard validScores.count >= minimumBaselineCount else {
            return nil
        }

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

enum CaptureQualityHistoryStore {
    static func acceptedScores(
        from defaults: UserDefaults = .standard
    ) -> [Float] {
        let values = defaults.array(
            forKey: AppPreferenceKey.acceptedFaceCaptureQualityScores
        ) ?? []
        return values.compactMap { value in
            guard let score = (value as? NSNumber)?.floatValue,
                  (0...1).contains(score) else {
                return nil
            }
            return score
        }
        .suffix(CaptureQualityPolicy.maximumHistoryCount)
        .map { $0 }
    }

    static func recordAccepted(
        _ evaluation: FaceCaptureQualityEvaluation,
        in defaults: UserDefaults = .standard
    ) {
        guard case .scored(let score) = evaluation,
              (0...1).contains(score) else {
            return
        }

        let scores = (
            acceptedScores(from: defaults) + [score]
        ).suffix(CaptureQualityPolicy.maximumHistoryCount)
        defaults.set(
            scores.map(Double.init),
            forKey: AppPreferenceKey.acceptedFaceCaptureQualityScores
        )
    }
}
