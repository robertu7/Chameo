@preconcurrency import CoreLocation
import Foundation

@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    private static let requestTimeout = Duration.seconds(15)

    private let manager = CLLocationManager()
    private var locationContinuations: [CheckedContinuation<CLLocation?, Never>] = []
    private var authorizationContinuations: [CheckedContinuation<Bool, Never>] = []
    private var authorizationTimeoutTask: Task<Void, Never>?
    private var locationTimeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isPermissionDenied: Bool {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    func requestCurrentLocation() async -> CLLocation? {
        let authorized = await ensureAuthorized()
        guard authorized else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            locationContinuations.append(continuation)
            guard locationContinuations.count == 1 else {
                return
            }

            manager.requestLocation()
            locationTimeoutTask = Task { [weak self] in
                try? await Task.sleep(for: Self.requestTimeout)
                guard !Task.isCancelled else {
                    return
                }
                self?.finishLocationRequest(with: nil)
            }
        }
    }

    private func ensureAuthorized() async -> Bool {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse, .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                authorizationContinuations.append(continuation)
                if authorizationContinuations.count == 1 {
                    manager.requestWhenInUseAuthorization()
                    authorizationTimeoutTask = Task { [weak self] in
                        try? await Task.sleep(for: Self.requestTimeout)
                        guard !Task.isCancelled else {
                            return
                        }
                        self?.finishAuthorizationRequest(with: false)
                    }
                }
            }
        @unknown default:
            return false
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let authorizationStatus = manager.authorizationStatus
        Task { @MainActor in
            switch authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse, .authorized:
                finishAuthorizationRequest(with: true)
            case .denied, .restricted:
                finishAuthorizationRequest(with: false)
                finishLocationRequest(with: nil)
            case .notDetermined:
                break
            @unknown default:
                finishAuthorizationRequest(with: false)
                finishLocationRequest(with: nil)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            finishLocationRequest(with: locations.last)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            finishLocationRequest(with: nil)
        }
    }

    private func finishAuthorizationRequest(with isAuthorized: Bool) {
        authorizationTimeoutTask?.cancel()
        authorizationTimeoutTask = nil

        let continuations = authorizationContinuations
        authorizationContinuations.removeAll()
        continuations.forEach { $0.resume(returning: isAuthorized) }
    }

    private func finishLocationRequest(with location: CLLocation?) {
        locationTimeoutTask?.cancel()
        locationTimeoutTask = nil

        let continuations = locationContinuations
        locationContinuations.removeAll()
        continuations.forEach { $0.resume(returning: location) }
    }
}

enum LocationNameService {
    static func name(for location: CLLocation?) async -> String {
        guard let location else {
            return "No location"
        }

        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else {
                return coordinateName(for: location)
            }

            let city = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea
            let country = placemark.country
            let parts = [city, country].compactMap { $0 }.filter { !$0.isEmpty }
            return parts.isEmpty ? coordinateName(for: location) : parts.joined(separator: ", ")
        } catch {
            return coordinateName(for: location)
        }
    }

    private static func coordinateName(for location: CLLocation) -> String {
        String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
    }
}
