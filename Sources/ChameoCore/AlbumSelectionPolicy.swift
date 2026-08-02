import Foundation

public struct AlbumSelectionCandidate: Equatable, Sendable {
    public let identifier: String
    public let eligibleChameoCount: Int

    public init(identifier: String, eligibleChameoCount: Int) {
        self.identifier = identifier
        self.eligibleChameoCount = eligibleChameoCount
    }
}

public enum AlbumSelectionPolicy {
    public static func saveDestination(
        from candidates: [AlbumSelectionCandidate],
        rememberedIdentifier: String?
    ) -> String? {
        if let rememberedIdentifier,
           candidates.contains(where: { $0.identifier == rememberedIdentifier }) {
            return rememberedIdentifier
        }
        return candidates.sorted {
            if $0.eligibleChameoCount != $1.eligibleChameoCount {
                return $0.eligibleChameoCount > $1.eligibleChameoCount
            }
            return $0.identifier < $1.identifier
        }.first?.identifier
    }
}

public enum ChameoAssetEligibility {
    public static func isEligible(isPhoto: Bool, creationDate: Date?) -> Bool {
        isPhoto && creationDate != nil
    }
}
