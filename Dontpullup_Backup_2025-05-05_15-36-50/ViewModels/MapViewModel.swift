import SwiftUI
import MapKit
@preconcurrency import CoreLocation
import FirebaseFirestore
import FirebaseAuth
import AVKit
import UIKit

@MainActor
class MapViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var userLocation: CLLocation?
    @Published var isLocationAuthorized = false
    @Published var isLocationServicesEnabled = false
    @Published var isTrackingUserLocation = false
    @Published var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @Published var pins: [Pin] = []
    @Published var selectedFilters: Set<IncidentType> = []
    @Published var showingIncidentPicker = false
    @Published var showingHelp = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var isEditMode = false
    @Published var mapType: MKMapType = .standard
    @Published var mapRegion: MKCoordinateRegion?
    @Published var showingOnlyMyPins = false
    @Published var pendingCoordinate: CLLocationCoordinate2D?
    @Published var isRequestingLocation = false
    // Flag to remember that the user tapped center button before granting permission
    private var shouldCenterAfterAuthorization = false
    
    // MARK: - Private Properties
    private let locationManager: CLLocationManager
    private let db = Firestore.firestore()
    
    // MARK: - Computed Properties
    var filteredPins: [Pin] {
        pins.filter { pin in
            if showingOnlyMyPins {
                guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
                return pin.userId == currentUserId
            }
            return selectedFilters.isEmpty || selectedFilters.contains(pin.incidentType)
        }
    }
    
    // MARK: - User Actions
    func toggleFilter(_ type: IncidentType) {
        if selectedFilters.contains(type) {
            selectedFilters.remove(type)
        } else {
            selectedFilters.insert(type)
        }
    }
    
    func toggleMyPinsFilter() {
        showingOnlyMyPins.toggle()
    }
    
    func toggleMapType() {
        mapType = mapType == .standard ? .hybrid : .standard
        // Reset mapRegion to trigger UI update (optional)
        mapRegion = mapRegion // no-op to notify observers
    }
    
    func toggleEditMode() {
        isEditMode.toggle()
    }
    
    func zoomIn() {
        let currentRegion = mapRegion ?? region
        let newSpan = MKCoordinateSpan(
            latitudeDelta: currentRegion.span.latitudeDelta * 0.5,
            longitudeDelta: currentRegion.span.longitudeDelta * 0.5
        )
        mapRegion = MKCoordinateRegion(center: currentRegion.center, span: newSpan)
    }
    
    func zoomOut() {
        let currentRegion = mapRegion ?? region
        let newSpan = MKCoordinateSpan(
            latitudeDelta: currentRegion.span.latitudeDelta * 2,
            longitudeDelta: currentRegion.span.longitudeDelta * 2
        )
        mapRegion = MKCoordinateRegion(center: currentRegion.center, span: newSpan)
    }
    
    func centerOnUserLocation() {
        // Request permission if not authorized
        if !isLocationAuthorized {
            // Defer centering until we get authorization and a location fix
            shouldCenterAfterAuthorization = true
            requestLocationPermission()
            return
        }
        
        guard let location = userLocation else {
            showAlert = true
            alertMessage = "Unable to determine your location"
            return
        }
        
        // Set region to a 200-foot radius view - approximately the drop pin range
        // 200 feet = ~60 meters, so we need a span that shows roughly 120m total width
        // 0.001 degrees of latitude/longitude is approximately 111 meters at the equator
        // So we use approximately 0.0011 (~120m) as our span
        mapRegion = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.0011, longitudeDelta: 0.0011)
        )
        // Make sure we're not tracking continuously
        isTrackingUserLocation = false
        // This is just a one-time update for pin dropping purposes
    }
    
    func getCurrentLocation() async -> CLLocation? {
        return userLocation
    }
    
    func initiatePinDropVerification(at coordinate: CLLocationCoordinate2D) {
        // First ensure we have location permission
        if !isLocationAuthorized {
            print("[MapViewModel] Requesting permission before pin drop verification")
            shouldCenterAfterAuthorization = true // Use this flag to resume the pin drop
            pendingCoordinate = coordinate // Store the coordinate for later
            requestLocationPermission()
            return
        }
        
        guard let userLocation = userLocation else {
            print("[MapViewModel] Pin drop failed - user location not available")
            showAlert = true
            alertMessage = "Unable to determine your location"
            return
        }
        
        print("[MapViewModel] Verifying pin distance from user location")
        let pinLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distance = userLocation.distance(from: pinLocation)
        
        if distance <= 200 * 0.3048 { // 200 feet in meters
            print("[MapViewModel] Pin within 200 feet - opening incident picker")
            pendingCoordinate = coordinate
            showingIncidentPicker = true
        } else {
            print("[MapViewModel] Pin too far from user - \(distance) meters")
            showAlert = true
            alertMessage = "You can only drop pins within 200 feet of your location"
        }
    }
    
    func userCanEditPin(_ pin: Pin) -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        return pin.userId == currentUserId
    }
    
    func getCachedVideo(for videoURL: String) -> Data? {
        // TODO: Implement actual caching with FileManager or a caching library
        // This is a placeholder implementation
        return nil
    }
    
    func cacheVideo(from remoteURL: URL, key: String) async throws {
        // TODO: Implement actual video caching
        // This is a placeholder implementation that just downloads the data
        do {
            let _ = try await URLSession.shared.data(from: remoteURL)
            // In a real implementation, you would save this data to the cache
            print("[MapViewModel] Downloaded video data from \(remoteURL)")
        } catch {
            print("[MapViewModel] Error caching video: \(error.localizedDescription)")
            throw error
        }
    }
    
    func showError(_ message: String) {
        showAlert = true
        alertMessage = message
    }
    
    // MARK: - Location Management
    /// Verifies location services and current authorization status, requesting permission when needed.
    @MainActor
    func checkAndRequestLocationPermission() {
        // First, ensure Location Services are enabled on the device.
        let servicesEnabled = CLLocationManager.locationServicesEnabled()
        isLocationServicesEnabled = servicesEnabled
        guard servicesEnabled else {
            showAlert = true
            alertMessage = "Location services are disabled. Please enable them in Settings."
            return
        }

        // Evaluate the current authorization state.
        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            // We haven't asked yet – trigger the system prompt.
            requestLocationPermission()
        default:
            // For all other states (.authorized*, .denied, .restricted) route through the existing handler
            handleAuthorizationStatus(status)
        }
    }
    
    /// Requests `when-in-use` location permission from the user.
    /// If permission has already been granted this method is a no-op and the
    /// location manager will immediately start delivering updates.  If the
    /// user previously denied permission an alert is surfaced explaining why
    /// location access is required.
    @MainActor
    func requestLocationPermission() {
        // Don't directly access authorizationStatus on the main thread
        // Instead, trigger the authorization check which will call the delegate
        isRequestingLocation = true
        
        // Create a local copy to access from background thread
        let localManager = locationManager
        
        // Dispatch the permission request to a background thread
        Task.detached {
            localManager.requestWhenInUseAuthorization()
        }
    }

    /// Centralised handler that translates `CLAuthorizationStatus` into
    /// published state and starts/stops updates accordingly.
    private func handleAuthorizationStatus(_ status: CLAuthorizationStatus) {
        print("[MapViewModel] Handling authorization status change: \(status.rawValue)")
        
        // Update the published state
        isLocationAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("[MapViewModel] Location authorized - fetching current location")
            // If authorized and this is app launch (or we need to refresh), get an initial fix
            isRequestingLocation = true
            // The actual request will happen in locationManagerDidChangeAuthorization
            
        case .notDetermined:
            // Wait for user to respond to system dialog
            print("[MapViewModel] Location permission not determined yet")
            
        case .denied, .restricted:
            print("[MapViewModel] Location access denied or restricted")
            // Show alert if user tries to use location-dependent features
            showAlert = true
            alertMessage = "Location access is required to use the map features. Enable it in Settings → Privacy → Location Services."
            
        @unknown default:
            print("[MapViewModel] Unknown location authorization status")
        }
    }

    // MARK: - Pin Management
    
    /// Drops a pin at the pending coordinate with the specified incident type
    func dropPin(for incidentType: IncidentType) {
        guard let pendingCoordinate = pendingCoordinate, 
              let currentUserId = Auth.auth().currentUser?.uid else {
            showAlert = true
            alertMessage = "Unable to drop pin. Please try again."
            showingIncidentPicker = false
            return
        }
        
        let pinId = UUID().uuidString
        let newPin = Pin(
            id: pinId,
            coordinate: pendingCoordinate,
            incidentType: incidentType,
            videoURL: "", // You would add a real URL after video upload
            userId: currentUserId
        )
        
        // Add to Firestore
        Task {
            do {
                let data: [String: Any] = [
                    "latitude": pendingCoordinate.latitude,
                    "longitude": pendingCoordinate.longitude,
                    "type": incidentType.firestoreType,
                    "videoURL": "",
                    "userId": currentUserId,
                    "timestamp": Timestamp(),
                    "deviceID": UIDevice.current.identifierForVendor?.uuidString ?? ""
                ]
                
                try await db.collection("pins").document(pinId).setData(data)
                
                // Update local pins array
                DispatchQueue.main.async {
                    self.pins.append(newPin)
                    self.pendingCoordinate = nil
                    self.showingIncidentPicker = false
                }
            } catch {
                print("[MapViewModel] Error adding pin: \(error.localizedDescription)")
                showAlert = true
                alertMessage = "Failed to drop pin: \(error.localizedDescription)"
                showingIncidentPicker = false
            }
        }
    }
    
    /// Deletes a pin from Firestore
    func deletePin(_ pin: Pin) async throws {
        do {
            try await db.collection("pins").document(pin.id).delete()
            // Update local pins array
            DispatchQueue.main.async {
                self.pins.removeAll { $0.id == pin.id }
            }
        } catch {
            print("[MapViewModel] Error deleting pin: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Initialization
    override init() {
        // Initialize with a temporary instance to avoid main thread blocking
        self.locationManager = CLLocationManager()
        super.init()
        
        // Defer real setup to after initialization
        Task { @MainActor in
            // Replace with properly configured instance
            self.locationManager.delegate = self
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
            
            // Initialize with default states
            self.isLocationServicesEnabled = false
            self.isLocationAuthorized = false
            
            // Defer location checks until after UI is ready
            self.deferredLocationSetup()
            
            // Load pins in parallel
            self.loadPins()
        }
    }
    
    /// Deferred location setup that runs after initialization
    /// to prevent UI blocking during app launch
    private func deferredLocationSetup() {
        Task.detached {
            // Short delay to ensure UI is ready
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            
            // Check location services status on background thread
            let servicesEnabled = CLLocationManager.locationServicesEnabled()
            
            // Update UI on main thread
            await MainActor.run {
                print("[MapViewModel] Location services enabled: \(servicesEnabled)")
                self.isLocationServicesEnabled = servicesEnabled
                
                if !servicesEnabled {
                    self.showAlert = true
                    self.alertMessage = "Location services are disabled. Please enable them in Settings."
                    return
                }
                
                // Don't check authorization status directly - let the delegate handle it
                // This prevents the UI blocking warning
                print("[MapViewModel] Waiting for authorization callback...")
                
                // The locationManagerDidChangeAuthorization delegate method will be called automatically
                // and will handle the authorization status check
                // Automatically ask for permission on first launch so the system dialog appears
                // This will be a no-op on subsequent launches once the user has responded.
                self.requestLocationPermission()
            }
        }
    }
    
    // MARK: - Pin Management
    private func loadPins() {
        // TODO: Implement pin loading from Firestore
    }
    
    /// Requests a single location update only after we've validated the authorization status
    @MainActor
    private func fetchCurrentLocation() {
        // Don't request location directly - set a flag and check status in the delegate callback
        isRequestingLocation = true
        
        // The actual request will happen in locationManagerDidChangeAuthorization
        // if we have proper permission
        print("[MapViewModel] Location update requested - waiting for authorization check")
    }

    @MainActor
    func centerMapOnUserLocation() {
        // Access location property directly (this is already on the MainActor)
        // instead of using locationManager.location
        guard let userLocation = userLocation else {
            showAlert = true
            alertMessage = "Unable to determine your location"
            return
        }
        
        // Use the userLocation instead of locationManager.location
        mapRegion = MKCoordinateRegion(
            center: userLocation.coordinate, 
            span: MKCoordinateSpan(latitudeDelta: 0.0011, longitudeDelta: 0.0011)
        )
    }
}

// MARK: - CLLocationManagerDelegate
extension MapViewModel: CLLocationManagerDelegate {
    // All delegate methods must be marked nonisolated to comply with Swift 6
    // Then we use Task { @MainActor in ... } to bridge back to MainActor
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Capture necessary state in local variables before crossing actor boundaries
        Task { @MainActor in
            let status = manager.authorizationStatus
            print("[MapViewModel] Location authorization status changed to: \(status.rawValue)")
            
            // Check if location services are enabled on a background thread
            Task.detached {
                let servicesEnabled = CLLocationManager.locationServicesEnabled()
                Task { @MainActor in
                    self.isLocationServicesEnabled = servicesEnabled
                }
            }
            
            self.handleAuthorizationStatus(status)
            
            // THIS IS THE KEY FIX - only request location from the delegate callback
            if (status == .authorizedWhenInUse || status == .authorizedAlways) {
                // If we had a pending location request, process it now
                if self.isRequestingLocation {
                    print("[MapViewModel] Authorization confirmed, requesting location update")
                    // Important: Create a local copy of locationManager
                    let localManager = self.locationManager
                    Task.detached {
                        localManager.requestLocation()
                    }
                    self.isRequestingLocation = false
                }
                
                // If we received authorization and there's a pending action, proceed with it
                if self.shouldCenterAfterAuthorization {
                    self.shouldCenterAfterAuthorization = false
                    
                    // If we have a pending coordinate, try the pin drop again
                    if let pendingCoordinate = self.pendingCoordinate {
                        print("[MapViewModel] Resuming pin drop after authorization")
                        // Get updated location first
                        let localManager = self.locationManager
                        Task.detached {
                            localManager.requestLocation()
                        }
                        // Give a moment for location to update before verification
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.initiatePinDropVerification(at: pendingCoordinate)
                        }
                    } else {
                        // Otherwise just center on user
                        print("[MapViewModel] Centering on user after authorization")
                        self.centerOnUserLocation()
                    }
                }
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Capture the important data before crossing actor boundaries
        let lastLocation = locations.last
        
        Task { @MainActor in
            guard let location = lastLocation else { return }
            print("[MapViewModel] Received location update: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            self.userLocation = location
            
            // If the user requested centering before authorization, do it now
            if self.shouldCenterAfterAuthorization {
                self.shouldCenterAfterAuthorization = false
                print("[MapViewModel] Centering after receiving location")
                self.centerOnUserLocation()
            }
            
            // We never do continuous tracking - the centerOnUserLocation method
            // will be called explicitly when the user taps the center button
            
            // Load pins if needed
            if self.pins.isEmpty {
                print("[MapViewModel] Pins array is empty, attempting to reload pins.")
                self.loadPins()
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Capture error information before crossing actor boundaries
        _ = error is CLError
        _ = (error as? CLError)?.code
        let errorMessage = error.localizedDescription
        
        Task { @MainActor in
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    // User denied permission
                    print("[MapViewModel] Location access denied")
                    self.showAlert = true
                    self.alertMessage = "Location access is required for this app. Please enable it in Settings."
                
                case .network:
                    // Network issues
                    print("[MapViewModel] Location network error")
                    self.showAlert = true
                    self.alertMessage = "Unable to determine location due to network issues."
                
                case .locationUnknown:
                    // Can't get a fix right now, but might work later
                    print("[MapViewModel] Location temporarily unavailable")
                    // Don't show alert for this - it's often transient
                    
                default:
                    print("[MapViewModel] Location error: \(clError.code.rawValue) - \(clError.localizedDescription)")
                    // For other errors, only show alert for user-initiated actions
                    if self.shouldCenterAfterAuthorization {
                        self.showAlert = true
                        self.alertMessage = "Unable to determine your location. Please try again."
                        self.shouldCenterAfterAuthorization = false
                    }
                }
            } else {
                // Generic error handler
                print("[MapViewModel] Location manager failed with error: \(errorMessage)")
            }
        }
    }
} 
