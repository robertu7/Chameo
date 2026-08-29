import Foundation

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
