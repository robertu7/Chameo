import CoreLocation
import Foundation

@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
    private var authorizationContinuation: CheckedContinuation<Bool, Never>?

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
            locationContinuation = continuation
            manager.requestLocation()
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
                authorizationContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        @unknown default:
            return false
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse, .authorized:
                authorizationContinuation?.resume(returning: true)
                authorizationContinuation = nil
            case .denied, .restricted:
                authorizationContinuation?.resume(returning: false)
                authorizationContinuation = nil
                locationContinuation?.resume(returning: nil)
                locationContinuation = nil
            case .notDetermined:
                break
            @unknown default:
                authorizationContinuation?.resume(returning: false)
                authorizationContinuation = nil
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            locationContinuation?.resume(returning: locations.last)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
        }
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
