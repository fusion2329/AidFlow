import CoreLocation
import Foundation

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var snapshot: IncidentLocation?
    @Published var statusText = "Location not captured".afLocalized

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var isCapturing = false
    private var reverseGeocodeRequestID = UUID()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
            return
        }

        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            statusText = "Location permission needed".afLocalized
            return
        }

        guard !isCapturing else { return }
        isCapturing = true
        statusText = "Capturing location...".afLocalized
        manager.requestLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        reverseGeocode(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isCapturing = false
        statusText = "Location unavailable".afLocalized
    }

    private func reverseGeocode(_ location: CLLocation) {
        geocoder.cancelGeocode()
        let requestID = UUID()
        reverseGeocodeRequestID = requestID

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }
            guard self.reverseGeocodeRequestID == requestID else { return }

            let placemark = placemarks?.first
            let addressParts = [
                placemark?.subThoroughfare,
                placemark?.thoroughfare,
                placemark?.locality,
                placemark?.administrativeArea,
                placemark?.postalCode,
                placemark?.country
            ]
            let address = addressParts.compactMap { $0 }.joined(separator: ", ")
            let fallback = "Address unavailable".afLocalized
            let nearbyStreet = [
                placemark?.areasOfInterest?.first,
                placemark?.subLocality,
                placemark?.thoroughfare
            ]
            .compactMap { $0 }
            .first { candidate in
                guard let thoroughfare = placemark?.thoroughfare else { return true }
                return candidate != thoroughfare
            }

            DispatchQueue.main.async {
                self.isCapturing = false
                self.snapshot = IncidentLocation(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    address: address.isEmpty ? fallback : address,
                    nearbyStreet: nearbyStreet,
                    capturedAt: Date()
                )
                self.statusText = "Location captured".afLocalized
            }
        }
    }
}
