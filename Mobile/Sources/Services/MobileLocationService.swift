@preconcurrency import CoreLocation
import ChameoCore
import Foundation

@MainActor
final class MobileLocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CaptureLocation?, Never>?
    private var timeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestAuthorizationIfNeeded() {
        guard manager.authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    func captureLocation() async -> CaptureLocation? {
        guard continuation == nil else { return nil }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            return nil
        case .authorizedAlways, .authorizedWhenInUse:
            break
        @unknown default:
            return nil
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { return }
                self?.finish(nil)
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        let location = locations.last.map {
            CaptureLocation(
                latitude: $0.coordinate.latitude,
                longitude: $0.coordinate.longitude,
                altitude: $0.altitude,
                horizontalAccuracy: $0.horizontalAccuracy,
                capturedAt: $0.timestamp
            )
        }
        Task { @MainActor in finish(location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in finish(nil) }
    }

    private func finish(_ location: CaptureLocation?) {
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation?.resume(returning: location)
        continuation = nil
    }
}
