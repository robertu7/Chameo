import Foundation

public struct CaptureLocation: Codable, Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double
    public let horizontalAccuracy: Double
    public let capturedAt: Date

    public init(
        latitude: Double,
        longitude: Double,
        altitude: Double,
        horizontalAccuracy: Double,
        capturedAt: Date
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.capturedAt = capturedAt
    }
}

public struct PendingChameoMetadata: Codable, Equatable, Sendable {
    public let capturedAt: Date
    public let location: CaptureLocation?
    public let faceCaptureQualityScore: Float?

    public init(
        capturedAt: Date,
        location: CaptureLocation?,
        faceCaptureQualityScore: Float? = nil
    ) {
        self.capturedAt = capturedAt
        self.location = location
        self.faceCaptureQualityScore = faceCaptureQualityScore
    }
}
