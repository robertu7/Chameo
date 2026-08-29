import ChameoCore
import Foundation

nonisolated enum MobileCaptureQualityStore {
    private static let key = "acceptedFaceCaptureQualityScores"

    static func acceptedScores(defaults: UserDefaults = .standard) -> [Float] {
        (defaults.array(forKey: key) ?? []).compactMap {
            guard let score = ($0 as? NSNumber)?.floatValue, (0...1).contains(score) else {
                return nil
            }
            return score
        }
        .suffix(CaptureQualityPolicy.maximumHistoryCount)
        .map { $0 }
    }

    static func record(score: Float?, defaults: UserDefaults = .standard) {
        guard let score, (0...1).contains(score) else { return }
        let values = (acceptedScores(defaults: defaults) + [score])
            .suffix(CaptureQualityPolicy.maximumHistoryCount)
        defaults.set(values.map(Double.init), forKey: key)
    }
}
