import SwiftUI
import MapKit
import CoreLocation
import AVKit
import Dispatch

// Firebase imports
#if canImport(Firebase)
import Firebase
#endif

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

// Platform-specific UI code
#if canImport(UIKit)
import UIKit
#endif

@MainActor
class MapViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var userLocation: CLLocation?
    @Published var isLocationAuthorized = false
    @Published var isLocationServicesEnabled = false
    @Published var isTrackingUserLocation = false
    @Published var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060), // Default to NYC
        span: MKCoordinateSpan(latitudeDelta: 0.001373, longitudeDelta: 0.001373) // Span similar to MapView's initial
    )
    @Published var pins: [Pin] = []
    @Published var selectedFilters: Set<IncidentType> = []
    @Published var showingIncidentPicker = false
    @Published var showingHelp = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var alertTitle: String? = nil
    @Published var isEditMode = false
    @Published var mapType: MKMapType = .standard
    @Published var mapRegion: MKCoordinateRegion?
    @Published var showingOnlyMyPins = false
    @Published var pendingCoordinate: CLLocationCoordinate2D?
    @Published var isRequestingLocation = false
    @Published var currentlyPlayingVideoId: String?
    @Published var pendingVideoData: Data?
    @Published var uploadProgress: Double = 0
    @Published var reportStep: ReportStep?   // nil = no sheet
    @Published var reportDraft = PinDraft()  // holds coord/type/url
    @Published var isLimitedFunctionalityDueToLocationDenial: Bool = false
    // Flag to remember that the user tapped center button before granting permission
    private var shouldCenterAfterAuthorization = false
    private var hasPromptedForInitialPermission = false
    
    // Alert queue to prevent multiple alerts
    private var alertQueue: [String] = []
    private var isShowingAlert = false
    
    // Add AuthState
    var authState: AuthState
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    
    // Use direct Firestore reference to prevent module errors
    #if canImport(FirebaseFirestore)
    private let db = FirebaseFirestore.Firestore.firestore()
    #else
    private let db: Any? = nil // Fallback for non-Firebase environments
    #endif
    
    // MARK: - Computed Properties
    var filteredPins: [Pin] {
        pins.filter { pin in
            if showingOnlyMyPins {
                #if canImport(FirebaseAuth)
                guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
                return pin.userId == currentUserId
                #else
                return false
                #endif
            }
            return selectedFilters.isEmpty || selectedFilters.contains(pin.incidentType)
        }
    }
    
    // MARK: - Firestore Operations
    
    /// Reports a video with provided information
    /// - Parameters:
    ///   - email: Email address of the person reporting
    ///   - reason: Reason for reporting
    ///   - videoId: ID of the video being reported
    /// - Returns: No return value
    /// - Throws: FirebaseError if the operation fails
    func reportVideo(email: String, reason: String, videoId: String) async throws {
        let report: [String: Any] = [
            "email": email,
            "reason": reason,
            "videoId": videoId,
            "timestamp": Date().timeIntervalSince1970,
            "status": "pending"
        ]
        
        try await db.collection("flaggedVideos").addDocument(data: report)
        print("[MapViewModel] Flag report submitted successfully for video \(videoId)")
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
        mapRegion = mapRegion
    }
    
    func toggleEditMode() {
        isEditMode.toggle()
    }
    
    // MARK: - Map Region Management
    
    /// Validates and ensures map region values are within acceptable bounds
    private func validateRegion(_ region: MKCoordinateRegion) -> MKCoordinateRegion {
        // Use our coordinate extension to validate the center coordinate
        let validCenter = region.center.validated()
        
        // Ensure span values are positive and within reasonable limits
        let minSpan = 0.0001 // Minimum span to prevent extreme zoom
        let maxSpan = 180.0  // Maximum span (half the world)
        
        let validLatDelta = max(min(region.span.latitudeDelta, maxSpan), minSpan)
        let validLongDelta = max(min(region.span.longitudeDelta, maxSpan), minSpan)
        
        // Check for NaN/Infinity in spans
        let span = MKCoordinateSpan(
            latitudeDelta: validLatDelta.isNaN || validLatDelta.isInfinite ? minSpan : validLatDelta,
            longitudeDelta: validLongDelta.isNaN || validLongDelta.isInfinite ? minSpan : validLongDelta
        )
        
        // Construct validated region
        return MKCoordinateRegion(
            center: validCenter,
            span: span
        )
    }
    
    /// Sets the map's region to center on the user's location with appropriate zoom level
    func centerOnUserLocation() {
        guard let userCoordinate = userLocation?.coordinate else {
            showAlert = true
            alertMessage = "Unable to determine your location. Please check your location services."
            return
        }
        
        let region = validateRegion(MKCoordinateRegion(
            center: userCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
        
        mapRegion = region
    }
    
    /// Sets the map's region to a 200-foot range around the user's location
    func zoomToRangeAroundUser() {
        guard let userCoordinate = userLocation?.coordinate else {
            showAlert = true
            alertMessage = "Unable to determine your location. Please check your location services."
            return
        }
        
        // Approximately 200 feet in degrees latitude/longitude
        let span = MKCoordinateSpan(latitudeDelta: 0.001373, longitudeDelta: 0.001373)
        
        let region = validateRegion(MKCoordinateRegion(
            center: userCoordinate,
            span: span
        ))
        
        mapRegion = region
    }
    
    /// Zooms in the map view
    func zoomIn() {
        guard let mapRegion = mapRegion ?? getDefaultRegion() else { return }
        
        // Calculate new span for zooming in (reduce by 25%)
        let newSpan = MKCoordinateSpan(
            latitudeDelta: max(mapRegion.span.latitudeDelta * 0.75, 0.0001),
            longitudeDelta: max(mapRegion.span.longitudeDelta * 0.75, 0.0001)
        )
        
        let newRegion = validateRegion(MKCoordinateRegion(
            center: mapRegion.center,
            span: newSpan
        ))
        
        self.mapRegion = newRegion
    }
    
    /// Zooms out the map view
    func zoomOut() {
        guard let mapRegion = mapRegion ?? getDefaultRegion() else { return }
        
        // Calculate new span for zooming out (increase by 25%)
        let newSpan = MKCoordinateSpan(
            latitudeDelta: min(mapRegion.span.latitudeDelta * 1.25, 180.0),
            longitudeDelta: min(mapRegion.span.longitudeDelta * 1.25, 180.0)
        )
        
        let newRegion = validateRegion(MKCoordinateRegion(
            center: mapRegion.center,
            span: newSpan
        ))
        
        self.mapRegion = newRegion
    }
    
    /// Returns the current map region or a default region if none is set
    private func getDefaultRegion() -> MKCoordinateRegion? {
        if let userLocation = userLocation {
            return MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        return nil
    }
    
    /// Ensures that a usable location is available within a short timeout.
    /// Returns `true` if `userLocation` is already populated or becomes
    /// available within the timeout window, otherwise `false`.
    func checkLocationAvailability() async -> Bool {
        // 1. Must be authorized.
        guard isLocationAuthorized else { return false }

        // 2. Device-level services need to be enabled.
        guard await checkLocationServicesEnabled() else { return false }

        // 3. If we already have a fix, we're done.
        if userLocation != nil { return true }

        // 4. Otherwise request a one-time location and await the helper.
        locationManager.requestLocation()

        //   Re-use the existing getCurrentLocation() helper which already
        //   handles its own timeout and MainActor isolation.
        let location = await getCurrentLocation()
        return location != nil
    }
    
    /// Toggles continuous location tracking mode
    func toggleLocationTracking() {
        isTrackingUserLocation.toggle()
        
        if isTrackingUserLocation {
            // Start continuous updates if tracking is enabled
            locationManager.startUpdatingLocation()
            // Also center the map on the user
            if let location = userLocation {
                mapRegion = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.0011, longitudeDelta: 0.0011)
                )
            }
        } else {
            // Stop continuous updates if tracking is disabled
            locationManager.stopUpdatingLocation()
        }
    }
    
    func getCurrentLocation() async -> CLLocation? {
        if let location = userLocation {
            return location
        }
        
        if !isLocationAuthorized || !isLocationServicesEnabled {
            return nil
        }
        
        let timeoutSeconds = 3.0
        do {
            return try await withTimeout(seconds: timeoutSeconds) {
                try await withCheckedThrowingContinuation { continuation in
                    var token: Any?
                    var hasResumed = false // Flag to track if continuation has been resumed
                    
                    // Define a function to safely resume continuation once
                    func safelyResume(with location: CLLocation) {
                        guard !hasResumed else { return }
                        hasResumed = true
                        
                        // Remove observer if it exists
                        if let token = token {
                            NotificationCenter.default.removeObserver(token)
                        }
                        
                        continuation.resume(returning: location)
                    }
                    
                    // Set up observer for location updates
                    token = NotificationCenter.default.addObserver(
                        forName: Notification.Name("LocationUpdated"),
                        object: nil,
                        queue: .main
                    ) { [weak self] _ in
                        Task { @MainActor in
                            guard let self = self, let location = self.userLocation else { return }
                            safelyResume(with: location)
                        }
                    }
                    
                    Task { @MainActor in
                        self.locationManager.requestLocation()
                        // Check if location is already available
                        if let location = self.userLocation {
                            safelyResume(with: location)
                        }
                    }
                }
            }
        } catch {
            return nil
        }
    }
    
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    private struct TimeoutError: Error, Sendable {}
    
    func initiatePinDropVerification(at coordinate: CLLocationCoordinate2D) {
        if !isLocationAuthorized {
            shouldCenterAfterAuthorization = true
            pendingCoordinate = coordinate
            requestLocationPermission()
            return
        }
        
        guard let userLocation = userLocation else {
            showAlert = true
            alertMessage = "Unable to determine your location"
            return
        }
        
        let pinLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distance = userLocation.distance(from: pinLocation)
        
        if distance <= 200 * 0.3048 {
            pendingCoordinate = coordinate
            showingIncidentPicker = true
        } else {
            showAlert = true
            alertMessage = "You can only drop pins within 200 feet of your location"
        }
    }
    
    func userCanEditPin(_ pin: Pin) -> Bool {
        #if canImport(FirebaseAuth)
        guard let currentUserId = FirebaseAuth.Auth.auth().currentUser?.uid else { return false }
        return pin.userId == currentUserId
        #else
        return false
        #endif
    }
    
    func getCachedVideo(for videoURL: String) -> Data? { return nil }
    
    func cacheVideo(from remoteURL: URL, key: String) async throws {
        do {
            let _ = try await URLSession.shared.data(from: remoteURL)
            print("[MapViewModel] Downloaded video data from \(remoteURL)")
        } catch {
            print("[MapViewModel] Error caching video: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Alert handling
    func showError(_ message: String, _ error: Error? = nil) {
        Task { @MainActor in
            let displayMessage: String
            
            if let error = error {
                // If in debug mode, include technical details
                #if DEBUG
                displayMessage = "\(message): \(error.userFriendlyMessage) (Debug: \(error.localizedDescription))"
                #else
                displayMessage = "\(message): \(error.userFriendlyMessage)"
                #endif
                
                // Set appropriate title based on error type
                if error.localizedDescription.contains("empty") || error.localizedDescription.contains("0 bytes") {
                    alertTitle = "Video Error"
                } else if error.localizedDescription.contains("location") || error.localizedDescription.contains("distance") {
                    alertTitle = "Location Error"
                } else if error.localizedDescription.contains("network") || error.localizedDescription.contains("connection") {
                    alertTitle = "Network Error"
                } else if error.localizedDescription.contains("permission") || error.localizedDescription.contains("denied") {
                    alertTitle = "Permission Error"
                } else {
                    alertTitle = "Error"
                }
            } else {
                displayMessage = message
                
                // Set appropriate title based on message content
                if message.contains("video") || message.contains("empty") || message.contains("bytes") {
                    alertTitle = "Video Error"
                } else if message.contains("location") || message.contains("distance") || message.contains("feet") {
                    alertTitle = "Location Error"
                } else if message.contains("network") || message.contains("connection") {
                    alertTitle = "Network Error"
                } else if message.contains("permission") || message.contains("denied") {
                    alertTitle = "Permission Error"
                } else {
                    alertTitle = "Error"
                }
            }
            
            // Add message to queue and try to show
            alertQueue.append(displayMessage)
            processAlertQueue()
        }
    }
    
    @MainActor
    private func processAlertQueue() {
        // Only proceed if we're not already showing an alert and we have messages
        guard !isShowingAlert, !alertQueue.isEmpty else { return }
        
        // Get the next message and mark as showing
        alertMessage = alertQueue.removeFirst()
        isShowingAlert = true
        showAlert = true
    }
    
    func clearPendingData() {
        Task { @MainActor in
            pendingCoordinate = nil
            pendingVideoData = nil
            uploadProgress = 0
            showingIncidentPicker = false
        }
    }
    
    // Separate function for async operations that need to be performed after clearing data
    @MainActor
    private func performPostClearOperations() async {
        // Any async operations that need to be performed after clearing data
        // can be added here
    }
    
    // MARK: - Location Management
    
    /// Gets the current authorization status safely off the main thread
    private func getAuthorizationStatus() async -> CLAuthorizationStatus {
        // Always run this in a detached task to ensure it's completely off the main thread
        // and properly isolated from the MainActor constraints
        return await Task.detached(priority: .userInitiated) { () -> CLAuthorizationStatus in
            // Create a new instance of CLLocationManager rather than accessing self.locationManager
            // to ensure we're completely isolated from MainActor constraints
            return CLLocationManager().authorizationStatus
        }.value
    }
    
    /// Checks if location services are enabled safely off the main thread
    private func checkLocationServicesEnabled() async -> Bool {
        // Run in a detached task to ensure it's completely off the main thread
        return await Task.detached(priority: .userInitiated) { () -> Bool in
            return CLLocationManager.locationServicesEnabled()
        }.value
    }

    private func checkInitialLocationStatus() async {
        // Execute CoreLocation queries away from the main thread first
        let servicesEnabled = await checkLocationServicesEnabled()
        let status = await getAuthorizationStatus()

        // Publish results back on the main actor
        await MainActor.run {
            self.isLocationServicesEnabled = servicesEnabled
            self.isLocationAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
            print("[MapViewModel] Initial check: Services enabled: \(servicesEnabled), Authorized: \(self.isLocationAuthorized) (Status: \(status.rawValue))")
            
            if !self.isLocationServicesEnabled || (!self.isLocationAuthorized && (status == .denied || status == .restricted)) {
                self.isLimitedFunctionalityDueToLocationDenial = true
                // We can also set the UserDefaults flag here if appropriate, though a dedicated func might be better
                // UserDefaults.standard.set(true, forKey: "userDeclinedLocationPermissions")
                print("[MapViewModel] Initial check: Location services/auth not sufficient. Limited functionality mode ON.")
            } else if self.isLocationAuthorized {
                self.isLimitedFunctionalityDueToLocationDenial = false
                // UserDefaults.standard.set(false, forKey: "userDeclinedLocationPermissions")
                print("[MapViewModel] Initial check: Location authorized. Limited functionality mode OFF.")
            } else {
                 // If status is .notDetermined, we don't set isLimitedFunctionalityDueToLocationDenial yet.
                 // It will be determined after the permission prompt.
                 print("[MapViewModel] Initial check: Location status .notDetermined. Waiting for prompt result.")
            }

            print("[MapViewModel] No automatic location requests - waiting for user action (center or pin drop).")
        }
    }

    @MainActor
    func forceLocationPermissionCheck() async throws {
        print("[MapViewModel] forceLocationPermissionCheck called.")
        // Move this off the main thread
        self.isLocationServicesEnabled = await checkLocationServicesEnabled()
        
        if !self.isLocationServicesEnabled {
            print("[MapViewModel] Location services disabled at device level.")
            self.isLocationAuthorized = false // Reflect this state
            self.isLimitedFunctionalityDueToLocationDenial = true // Set the flag
            UserDefaults.standard.set(true, forKey: "userDeclinedLocationPermissions") // Set user default
            alertMessage = "Location services are disabled. Please enable them in Settings."
            showAlert = true
            throw LocationError.servicesDisabled
        }

        // Get authorization status safely off the main thread
        let currentStatus = await getAuthorizationStatus()
        
        print("[MapViewModel] Current authorization status for force check: \(currentStatus.rawValue)")
        self.isLocationAuthorized = (currentStatus == .authorizedWhenInUse || currentStatus == .authorizedAlways)

        switch currentStatus {
        case .notDetermined:
            print("[MapViewModel] Authorization not determined, requesting WhenInUse.")
            isRequestingLocation = true // Indicate a request is in progress
            // We don't set isLimitedFunctionalityDueToLocationDenial here, wait for delegate.
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            print("[MapViewModel] Authorization denied or restricted. Guiding user to settings may be needed.")
            self.isLimitedFunctionalityDueToLocationDenial = true // Set the flag
            UserDefaults.standard.set(true, forKey: "userDeclinedLocationPermissions") // Set user default
            alertMessage = "Location access was denied. Please enable it in Settings to use location features."
            showAlert = true
            throw LocationError.permissionDenied
            // isLocationAuthorized is already false or will be set by delegate
        case .authorizedWhenInUse, .authorizedAlways:
            print("[MapViewModel] Already authorized.")
            self.isLimitedFunctionalityDueToLocationDenial = false // Clear the flag
            UserDefaults.standard.set(false, forKey: "userDeclinedLocationPermissions") // Clear user default
            // NO automatic location updates - only request if explicitly needed
            if shouldCenterAfterAuthorization {
                centerOnUserLocation()
                shouldCenterAfterAuthorization = false
            }
            if let coord = pendingCoordinate {
                initiatePinDropVerification(at: coord)
                pendingCoordinate = nil
            }
        @unknown default:
            print("[MapViewModel] Unknown authorization status: \(currentStatus.rawValue)")
            throw LocationError.unknown
        }
    }
    
    @MainActor
    func requestLocationPermission() {
        print("[MapViewModel] requestLocationPermission called.")
        
        // Move location services check off the main thread with Task
        Task {
            let servicesEnabled = await checkLocationServicesEnabled()
            
            await MainActor.run {
                self.isLocationServicesEnabled = servicesEnabled
                
                if !servicesEnabled {
                    print("[MapViewModel] Location services are disabled. Cannot request permission.")
                    self.isLocationAuthorized = false
                    alertMessage = "Location services are disabled. Please enable them in Settings."
                    showAlert = true
                    return
                }
                
                // Continue with permission request after verifying services are enabled
                Task {
                    let status = await getAuthorizationStatus()
                    await MainActor.run {
                        self.handleAuthorizationStatus(status)
                    }
                }
            }
        }
    }
    
    @MainActor
    private func handleAuthorizationStatus(_ status: CLAuthorizationStatus) {
        if status == .notDetermined {
            print("[MapViewModel] Status is .notDetermined. Requesting WhenInUse authorization.")
            isRequestingLocation = true
            locationManager.requestWhenInUseAuthorization()
        } else {
            print("[MapViewModel] Permission already determined (Status: \(status.rawValue)). Handling via forceLocationPermissionCheck or delegate.")
            // If already determined, let forceLocationPermissionCheck or delegate handle state
            // Potentially trigger force check if called directly and not .notDetermined
            Task { 
                do {
                    try await forceLocationPermissionCheck() 
                } catch {
                    print("[MapViewModel] Error during force location check: \(error)")
                }
            } 
        }
    }
    
    // MARK: - Pin Management
    func dropPin(for incidentType: IncidentType) {
        #if canImport(FirebaseAuth)
        guard let pendingCoordinate = pendingCoordinate,
              let currentUserId = FirebaseAuth.Auth.auth().currentUser?.uid else {
            showAlert = true
            alertMessage = "Unable to drop pin. Please try again."
            showingIncidentPicker = false
            return
        }
        
        let pinId = UUID().uuidString
        let _ = Pin(
            id: pinId,
            coordinate: pendingCoordinate,
            incidentType: incidentType,
            videoURL: "",
            userId: currentUserId
        )
        
        Task {
            do {
                let timestamp: Any
                #if canImport(FirebaseFirestore)
                timestamp = FirebaseFirestore.Timestamp()
                #else
                timestamp = Date().timeIntervalSince1970
                #endif
                
                let data: [String: Any] = [
                    "latitude": pendingCoordinate.latitude,
                    "longitude": pendingCoordinate.longitude,
                    "type": incidentType.firestoreType,
                    "videoURL": "",
                    "userId": currentUserId,
                    "timestamp": timestamp,
                    "deviceID": UIDevice.current.identifierForVendor?.uuidString ?? ""
                ]
                
                try await db.collection("pins").document(pinId).setData(data)
                await MainActor.run {
                    self.pins.append(Pin(
                        id: pinId,
                        coordinate: pendingCoordinate,
                        incidentType: incidentType,
                        videoURL: "",
                        userId: currentUserId
                    ))
                    self.pendingCoordinate = nil
                    self.showingIncidentPicker = false
                }
            } catch {
                print("[MapViewModel] Error adding pin: \(error.localizedDescription)")
                await MainActor.run {
                    showAlert = true
                    alertMessage = "Failed to drop pin: \(error.localizedDescription)"
                    showingIncidentPicker = false
                }
            }
        }
        #else
        showAlert = true
        alertMessage = "Firebase Auth not available. Unable to drop pin."
        showingIncidentPicker = false
        #endif
    }
    
    func deletePin(_ pin: Pin) async throws {
        do {
            try await db.collection("pins").document(pin.id).delete()
            await MainActor.run {
                self.pins.removeAll { $0.id == pin.id }
            }
        } catch {
            print("[MapViewModel] Error deleting pin: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Initialization
    init(authState: AuthState = AuthState.shared) {
        self.authState = authState
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update when moved at least 10 meters
        
        // Configure the session for precise indoor positioning
        if #available(iOS 14.0, *) {
            locationManager.activityType = .fitness // Prioritize accuracy over battery life
            locationManager.allowsBackgroundLocationUpdates = false
        }
        
        // Set up the notification observer
        NotificationCenter.default.addObserver(
            forName: .appDidBecomeActiveForLocationCheck,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            print("[MapViewModel] Initialized and subscribed to appDidBecomeActiveForLocationCheck notification.")
            
            Task {
                // Need to mark partial apply with await
                do {
                    // First check initial status
                    await self.checkInitialLocationStatus()
                    
                    // Only enforce location check if the app is already authorized
                    // to avoid immediately showing permission dialogs on startup
                    let isAuthorized = await MainActor.run { self.isLocationAuthorized }
                    if isAuthorized {
                        try await self.forceLocationPermissionCheck()
                    } else if !(await MainActor.run { self.hasPromptedForInitialPermission }) {
                        print("[MapViewModel] Ensuring initial permission prompt")
                        // Update this property on the main actor
                        await MainActor.run {
                            self.hasPromptedForInitialPermission = true
                        }
                        try await self.forceLocationPermissionCheck()
                    }
                } catch {
                    print("[MapViewModel] Error during location initialization: \(error)")
                }
            }
        }
        
        // Load pins from Firestore
        loadPins()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func loadPins() {
        // TODO: Implement pin loading from Firestore
        Task {
            do {
                print("[MapViewModel] Loading pins from Firestore")
                let loadedPins = try await FirestorePins.getAllPins()
                await MainActor.run {
                    self.pins = loadedPins
                    print("[MapViewModel] Successfully loaded \(loadedPins.count) pins")
                }
            } catch {
                print("[MapViewModel] Error loading pins: \(error.localizedDescription)")
                await MainActor.run {
                    self.showError("Failed to load incident markers", error)
                }
            }
        }
    }
    
    @MainActor
    private func fetchCurrentLocation() {
        if isLocationAuthorized {
            print("[MapViewModel] Fetching current location")
            locationManager.requestLocation()
        } else {
            print("[MapViewModel] Cannot fetch location: not authorized")
        }
    }
    
    @MainActor
    func centerMapOnUserLocation() {
        guard let userLocation = userLocation else {
            showAlert = true
            alertMessage = "Unable to determine your location"
            return
        }
        
        let newCenteredRegion = MKCoordinateRegion(
            center: userLocation.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.0011, longitudeDelta: 0.0011)
        )
        self.region = newCenteredRegion      // Update the ViewModel's main region state
        self.mapRegion = newCenteredRegion   // Signal the MapView to update
    }
    
    func continueWithLimitedFunctionality() {
        UserDefaults.standard.set(true, forKey: "userDeclinedLocationPermissions")
        showAlert = true
        alertMessage = "Some features like pin dropping will be unavailable without location access. Enable it later in Settings."
    }
    
    @objc private func refreshLocationPermissions() {
        Task {
            let servicesEnabled = await checkLocationServicesEnabled()
            await MainActor.run {
                self.isLocationServicesEnabled = servicesEnabled
                print("[MapViewModel] App returned to foreground, relying on delegate for authorization status")
            }
        }
    }
    
    /// Call from MainTabView.onAppear for one-time first launch prompt.
    @MainActor
    func ensureInitialPermissionPrompt() {
        print("[MapViewModel] Ensuring initial permission prompt")
        // Perform the check off-thread and then act on the result
        Task {
            let status = await getAuthorizationStatus()

            await MainActor.run {
                switch status {
                case .notDetermined:
                    print("[MapViewModel] Requesting location permission on initial load")
                    self.isRequestingLocation = true
                    self.locationManager.requestWhenInUseAuthorization()
                default:
                    print("[MapViewModel] Permission already determined: \(status.rawValue). Forcing a refresh check")
                    Task { 
                        do {
                            try await self.forceLocationPermissionCheck()
                        } catch {
                            print("[MapViewModel] Error during force location check: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Video Upload Service
    /// Helper class to handle video upload operations
    class VideoUploadService {
        private let storage = Storage.storage()
        
        func uploadVideo(pinId: String, videoURL: URL, metadata: StorageMetadata? = nil) async throws -> String {
            // Create a reference to Firebase Storage
            let storageRef = storage.reference().child("videos/\(pinId).mp4")
            let customMetadata = metadata ?? {
                let meta = StorageMetadata()
                meta.contentType = "video/mp4"
                return meta
            }()
            
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                // Create a semaphore to wait for the async operation
                let semaphore = DispatchSemaphore(value: 0)
                var uploadError: Error?
                var downloadURL: URL?
                
                // Start the upload task
                let uploadTask = storageRef.putFile(from: videoURL, metadata: customMetadata)
                
                // Create a class to hold and isolate the uploadTask
                let taskHolder = StorageTaskHolder(task: uploadTask)
                
                // Set up progress handler if needed
                let progressHandler = uploadTask.observe(.progress) { snapshot in
                    let percentComplete = Double(snapshot.progress?.completedUnitCount ?? 0) / Double(snapshot.progress?.totalUnitCount ?? 1) * 100
                    print("Upload is \(percentComplete)% complete")
                    
                    // Update progress in a properly isolated way
                    Task { @MainActor in
                        NotificationCenter.default.post(
                            name: .videoUploadProgressUpdated, 
                            object: nil, 
                            userInfo: ["progress": percentComplete/100.0]
                        )
                    }
                }
                
                // Set up completion handler
                let completionHandler = uploadTask.observe(.success) { _ in
                    // Get download URL
                    storageRef.downloadURL { url, error in
                        if let error = error {
                            uploadError = error
                            semaphore.signal()
                            return
                        }
                        
                        guard let url = url else {
                            uploadError = NSError(domain: "VideoUploadService", code: -1, 
                                               userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])
                            semaphore.signal()
                            return
                        }
                        
                        downloadURL = url
                        semaphore.signal()
                    }
                }
                
                // Set up error handler
                let errorHandler = uploadTask.observe(.failure) { snapshot in
                    uploadError = snapshot.error
                    semaphore.signal()
                }
                
                // Get all the values we need before the closure
                // to avoid capturing mutable state in the @Sendable closure
                let taskRef = taskHolder.task
                
                // Wait for completion (on a background thread)
                // Create a local, non-escaping function to use the task reference safely
                func handleCompletion() {
                    semaphore.wait()
                    
                    // Clean up observers using the captured reference 
                    taskRef?.removeObserver(withHandle: progressHandler)
                    taskRef?.removeObserver(withHandle: completionHandler)
                    taskRef?.removeObserver(withHandle: errorHandler)
                }
                
                // Execute the closure without capturing taskHolder
                DispatchQueue.global(qos: .userInitiated).async {
                    handleCompletion()
                    
                    // Handle result
                    if let error = uploadError {
                        continuation.resume(throwing: error)
                    } else if let url = downloadURL {
                        continuation.resume(returning: url.absoluteString)
                    } else {
                        continuation.resume(throwing: NSError(domain: "VideoUploadService", code: -2, 
                                                          userInfo: [NSLocalizedDescriptionKey: "Unknown upload error"]))
                    }
                }
            }
        }
    }

    // In MapViewModel class, replace the complex upload methods with:

    private let uploadService = VideoUploadService()

    // Replace the complex dropPinWithVideo method with this simplified version
    func dropPinWithVideo(for incidentType: IncidentType, videoURL: URL) async throws {
        guard let pendingCoordinate = pendingCoordinate,
              let currentUserId = Auth.auth().currentUser?.uid else {
            await MainActor.run {
                showAlert = true
                alertMessage = "Unable to drop pin. Please try again."
                showingIncidentPicker = false
            }
            return
        }
        
        let pinId = UUID().uuidString
        
        // Show upload progress
        await MainActor.run {
            uploadProgress = 0.01 // Start with non-zero progress
        }
        
        // Set up progress updates using MainActor dispatching
        // Create a property to hold the progress value
        let progressHolder = ProgressHolder()
        
        // Set up progress observer - store handle for later removal
        let progressObserver = NotificationCenter.default.addObserver(
            forName: .videoUploadProgressUpdated,
            object: nil,
            queue: .main
        ) { [weak progressHolder] notification in
            guard let progressHolder = progressHolder,
                  let progress = notification.userInfo?["progress"] as? Double else { return }
            
            // Update the holder first
            progressHolder.progress = progress
            
            // Post a notification for the MainActor to handle
            NotificationCenter.default.post(
                name: .uploadProgressUpdatedMainActor,
                object: nil,
                userInfo: ["progress": progress]
            )
        }
        
        do {
            // Upload video and get URL
            let remoteURL = try await uploadService.uploadVideo(pinId: pinId, videoURL: videoURL)
            
            // Create pin
            let newPin = Pin(
                id: pinId,
                coordinate: pendingCoordinate,
                incidentType: incidentType,
                videoURL: remoteURL,
                userId: currentUserId
            )
            
            // Save to Firestore
            try await savePinToFirestore(newPin)
            
            // Update local state
            await MainActor.run {
                self.pins.append(newPin)
                self.pendingCoordinate = nil
                self.showingIncidentPicker = false
                self.uploadProgress = 1.0
                
                // Reset progress after a delay - use proper actor isolation
                Task { 
                    try await Task.sleep(nanoseconds: 1_500_000_000)
                    // Use nonisolated way to dispatch to MainActor to avoid capturing self
                    await MainActor.run {
                        self.uploadProgress = 0
                    }
                }
                
                // Store the task for potential cancellation later using a detached @MainActor task
                // to avoid capturing self in the Sendable closure
                Task { @MainActor in
                    // This task storage isn't strictly necessary but helps with cleanup
                    // ... existing code ...
                }
            }
        } catch {
            await MainActor.run {
                showError("Failed to upload video", error)
                clearPendingData()
            }
        }
        
        // Remove the observer when done
        NotificationCenter.default.removeObserver(progressObserver)
    }

    // Simplified method to save pin to Firestore
    private func savePinToFirestore(_ pin: Pin) async throws {
        let data: [String: Any] = [
            "latitude": pin.coordinate.latitude,
            "longitude": pin.coordinate.longitude,
            "type": pin.incidentType.firestoreType,
            "videoURL": pin.videoURL,
            "userId": pin.userId,
            "timestamp": Timestamp(),
            "deviceID": UIDevice.current.identifierForVendor?.uuidString ?? ""
        ]
        
        try await db.collection("pins").document(pin.id).setData(data)
    }
    
    // MARK: - Pin Creation and Upload
    private func uploadVideoAndCreatePin(videoData: Data, pinDetails: PinDraft) {
        // Check if user is anonymous before proceeding with video operations
        if authState.isAnonymous {
            showError("Guests cannot upload videos.")
            reportStep = nil // Dismiss the report sheet
            self.authState.isLoading = false // Reset loading state if any
            return
        }

        self.authState.isLoading = true

        // ... rest of the method ...
    }

    /// Call when the user dismisses an alert presented by the View layer.
    /// Resets the `isShowingAlert` flag and shows the next queued alert if any.
    @MainActor
    func alertDismissed() {
        isShowingAlert = false
        alertTitle = nil
        processAlertQueue()
    }

    func startReportFlow(at coord: CLLocationCoordinate2D) {
        reportDraft = PinDraft(coordinate: coord)
        reportStep = .incidentType
    }
    
    @MainActor
    func upload(draft: PinDraft) async {
        // Check if user is anonymous AND trying to upload a video
        if authState.isAnonymous && draft.videoURL != nil {
            showError("Guests cannot upload videos.")
            reportStep = nil 
            return
        }

        // Generate a unique ID for the pin
        let pinId = UUID().uuidString
        print("[MapViewModel] Starting upload process for pin ID: \(pinId)")
        
        // Initialize the remote URL to an empty string
        var remoteURL = ""
        
        do {
            // Step 1: If there's a video URL, handle the video upload separately
            if let videoURL = draft.videoURL {
                // Verify file exists and is readable
                let fileManager = FileManager.default
                guard fileManager.fileExists(atPath: videoURL.path) else {
                    throw NSError(domain: "MapViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Video file not found at path: \(videoURL.path)"])
                }
                
                let fileSize = try fileManager.attributesOfItem(atPath: videoURL.path)[.size] as? UInt64 ?? 0
                print("[MapViewModel] Found video file at path: \(videoURL.path), size: \(fileSize) bytes")
                
                if fileSize == 0 {
                    throw NSError(domain: "MapViewModel", code: -2, userInfo: [NSLocalizedDescriptionKey: "Video file is empty (0 bytes)"])
                }
                
                // Show upload progress
                uploadProgress = 0.01 // Start with non-zero progress
                
                // Set up progress observation
                let progressObserver = NotificationCenter.default.addObserver(
                    forName: .videoUploadProgressUpdated,
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    guard let self = self,
                          let progress = notification.userInfo?["progress"] as? Double else { return }
                    // Update the progress using MainActor.run to avoid capturing self
                    Task { @MainActor in
                        self.uploadProgress = progress
                        print("[MapViewModel] Upload progress updated: \(Int(progress * 100))%")
                    }
                }
                
                do {
                    // Call StorageUploader with better error handling
                    print("[MapViewModel] Beginning StorageUploader.uploadIfNeeded for pin ID: \(pinId)")
                    remoteURL = try await StorageUploader.uploadIfNeeded(pinId: pinId, localURL: videoURL)
                    print("[MapViewModel] Video upload successful: \(remoteURL)")
                    
                    // Clean up temp file
                    do {
                        try FileManager.default.removeItem(at: videoURL)
                        print("[MapViewModel] Cleaned up temporary file at: \(videoURL.path)")
                    } catch {
                        print("[MapViewModel] Warning: Could not clean up temp file: \(error.localizedDescription)")
                    }
                } catch {
                    // Clean up notification observer
                    NotificationCenter.default.removeObserver(progressObserver)
                    
                    // Reset progress
                    uploadProgress = 0
                    
                    print("[MapViewModel] Video upload failed: \(error.localizedDescription)")
                    // Show error and rethrow
                    showError("Video upload failed", error)
                    throw error
                }
                
                // Clean up notification observer
                NotificationCenter.default.removeObserver(progressObserver)
                
                // Mark upload as complete
                uploadProgress = 1.0
                
                // Reset progress after a delay - use proper actor isolation
                Task { 
                    try await Task.sleep(nanoseconds: 1_500_000_000)
                    // Use nonisolated way to dispatch to MainActor to avoid capturing self
                    await MainActor.run {
                        self.uploadProgress = 0
                    }
                }
                
                // Store the task for potential cancellation later using a detached @MainActor task
                // to avoid capturing self in the Sendable closure
                Task { @MainActor in
                    // This task storage isn't strictly necessary but helps with cleanup
                    // ... existing code ...
                }
            }
            
            // Step 2: Create the Firestore document with proper error handling
            do {
                print("[MapViewModel] Creating Firestore document for pin ID: \(pinId)")
                try await createPinInFirestore(
                    id: pinId,
                    coordinate: draft.coordinate,
                    incidentType: draft.incidentType,
                    videoURL: remoteURL
                )
                print("[MapViewModel] Pin data saved to Firestore")
            } catch {
                print("[MapViewModel] Firestore document creation failed: \(error.localizedDescription)")
                showError("Could not save pin data", error)
                throw error
            }
            
            // Step 3: Update local data
            await updateLocalPins(draft: draft, pinId: pinId, remoteURL: remoteURL)
            print("[MapViewModel] Local pins updated")
            
            // Step 4: Cleanup
            pendingCoordinate = nil
            reportStep = nil
            
        } catch {
            // Main error handler - specific errors are already displayed in their own handlers
            print("[MapViewModel] Report creation failed: \(error.localizedDescription)")
            showError("Report creation failed", error)
        }
    }
    
    // Helper method to upload video
    @MainActor
    private func uploadVideo(pinId: String, videoURL: URL) async throws -> String {
        // Add missing try keyword for the async call
        return try await StorageUploader.uploadIfNeeded(pinId: pinId, localURL: videoURL)
    }
    
    // Helper method to create Firestore document
    @MainActor
    private func createPinInFirestore(id: String, coordinate: CLLocationCoordinate2D, 
                                     incidentType: IncidentType, videoURL: String) async throws {
        try await FirestorePins.addPin(
            id: id,
            coord: coordinate,
            type: incidentType,
            videoURL: videoURL
        )
    }
    
    // Helper method to update local pins
    @MainActor
    private func updateLocalPins(draft: PinDraft, pinId: String, remoteURL: String) async {
        // Add to local pins array 
        pins.append(draft.makePin(id: pinId, remote: remoteURL))
        
        // Refresh pins after adding a new one
        do {
            try await refreshPins()
        } catch {
            print("[MapViewModel] Error refreshing pins: \(error.localizedDescription)")
            self.showError("Failed to refresh incident markers", error)
        }
    }
    
    // Helper method to refresh pins from Firestore
    @MainActor
    func refreshPins() async throws {
        print("[MapViewModel] Refreshing pins from Firestore")
        let loadedPins = try await FirestorePins.getAllPins()
        self.pins = loadedPins
        print("[MapViewModel] Successfully refreshed \(loadedPins.count) pins")
    }
    
    // MARK: - Location Range Visualization and Management
    @MainActor
    class RangeVisualizationManager {
        private var circleOverlay: MKCircle?
        private var mapView: MKMapView?
        private let pinDropRange: CLLocationDistance = 200 * 0.3048 // 200 feet in meters
        
        // Initialize with map view
        func setMapView(_ mapView: MKMapView) {
            self.mapView = mapView
        }
        
        // Show range circle
        func showRangeCircle(at center: CLLocationCoordinate2D) {
            // Remove existing circle if any
            removeRangeCircle()
            
            // Create new circle
            let circle = MKCircle(center: center, radius: pinDropRange)
            circleOverlay = circle
            
            // Safely access the mapView on the main actor
            Task { @MainActor in
                mapView?.addOverlay(circle, level: .aboveRoads)
                
                // Animate it into view - also on the main actor
                UIView.animate(withDuration: 0.3) { [weak self] in
                    self?.mapView?.layoutIfNeeded()
                }
            }
        }
        
        // Remove range circle
        func removeRangeCircle() {
            if let circle = circleOverlay {
                // Safely remove overlay on the main actor
                Task { @MainActor in
                    mapView?.removeOverlay(circle)
                }
                circleOverlay = nil
            }
        }
        
        // Calculate if a coordinate is within the pin drop range - this can remain non-MainActor
        nonisolated func isCoordinateWithinRange(userLocation: CLLocationCoordinate2D, coordinate: CLLocationCoordinate2D) -> Bool {
            let userLocationCL = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
            let targetLocationCL = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            // This calculation doesn't involve UI or MainActor state
            let distance = userLocationCL.distance(from: targetLocationCL)
            let pinDropRange: CLLocationDistance = 200 * 0.3048 // 200 feet in meters
            return distance <= pinDropRange
        }
        
        // Get appropriate zoom level for 200-foot range - also safe to be non-MainActor
        nonisolated func zoomLevelForPinDropRange(at center: CLLocationCoordinate2D) -> MKCoordinateRegion {
            // 200 feet + a bit of margin (~250 feet)
            let pinDropRange: CLLocationDistance = 200 * 0.3048 // 200 feet in meters
            let spanDelta = pinDropRange * 1.25 / 111000 // Convert meters to degrees (1 degree ≈ 111km)
            
            // Create a span that fits the range circle with a bit of margin
            let span = MKCoordinateSpan(
                latitudeDelta: spanDelta,
                longitudeDelta: spanDelta 
            )
            
            return MKCoordinateRegion(center: center, span: span)
        }
    }

    // Add this property to MapViewModel
    private let rangeVisualizationManager = RangeVisualizationManager()

    // Add this method to initialize the range visualization manager
    func setupRangeVisualization(on mapView: MKMapView) {
        rangeVisualizationManager.setMapView(mapView)
    }

    // Replace the existing zoomToUserTight method with this enhanced version
    func zoomToUserTight() {
        Task {
            if let userLocation = await getCurrentLocation()?.coordinate {
                // Set region to the tight zoom level for pin dropping
                let region = rangeVisualizationManager.zoomLevelForPinDropRange(at: userLocation)
                
                await MainActor.run {
                    // Update the map region
                    mapRegion = region
                    
                    // Show the range circle
                    rangeVisualizationManager.showRangeCircle(at: userLocation)
                    
                    // Hide the range circle after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                        self?.rangeVisualizationManager.removeRangeCircle()
                    }
                }
            } else {
                await MainActor.run {
                    showError("Could not get your current location")
                }
            }
        }
    }

    // Replace isWithinPinDropRange with this improved version
    func isWithinPinDropRange(coordinate: CLLocationCoordinate2D) async -> Bool {
        // Get current location (or nil if not available/authorized)
        guard let userLocation = await getCurrentLocation() else {
            await MainActor.run {
                showError("Unable to verify your location")
            }
            return false
        }
        
        // Use the range visualization manager to check distance
        let within = rangeVisualizationManager.isCoordinateWithinRange(
            userLocation: userLocation.coordinate,
            coordinate: coordinate
        )
        
        // If not within range, show the range circle to help the user
        if !within {
            await MainActor.run {
                // Briefly show the range circle to indicate the allowed area
                rangeVisualizationManager.showRangeCircle(at: userLocation.coordinate)
                
                // Then hide it after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    self?.rangeVisualizationManager.removeRangeCircle()
                }
            }
        }
        
        return within
    }
    
    // Cycle through multiple map types instead of just two
    func cycleMapType() {
        switch mapType {
        case .standard:
            mapType = .hybrid
        case .hybrid:
            mapType = .satellite
        case .satellite:
            mapType = .mutedStandard
        case .mutedStandard:
            mapType = .standard
        default:
            mapType = .standard
        }
    }
    
    // Helper to get icon name for current map type
    func mapTypeIcon() -> String {
        switch mapType {
        case .standard:
            return "map"
        case .hybrid:
            return "globe.americas.fill"  
        case .satellite:
            return "camera.aperture"
        case .mutedStandard:
            return "map.fill"
        default:
            return "map"
        }
    }
    
    // Zoom limits (approx)
    private let minSpanDelta: CLLocationDegrees = 0.0003  // ~30-40 m
    private let maxSpanDelta: CLLocationDegrees = 1.0      // ~110 km
    
    func savePinAndVideo(coordinate: CLLocationCoordinate2D, incidentType: IncidentType, videoData: Data, description: String, isEmergency: Bool) {
        // Check if user is anonymous before proceeding with video operations
        if authState.isAnonymous {
            showError("Guests cannot upload videos.")
            // Dismiss the report flow or indicate failure appropriately
            reportStep = nil // Example: dismiss the report sheet
            return
        }

        Task {
            do {
                let videoURL = try await uploadVideoToStorage(videoData: videoData, fileExtension: "mp4")
                let newPin = Pin(id: UUID().uuidString, coordinate: coordinate, incidentType: incidentType, videoURL: videoURL.absoluteString, userId: Auth.auth().currentUser?.uid ?? "unknown")
                try await savePinToFirestore(newPin)
                pins.append(newPin)
                reportStep = nil // Dismiss sheet on success
            } catch {
                showError("Failed to save pin with video", error)
            }
        }
    }
    
    private func uploadVideoToStorage(videoData: Data, fileExtension: String) async throws -> URL {
        let pinId = UUID().uuidString
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileURL = tempDir.appendingPathComponent("temp_video_\(pinId).\(fileExtension)")
        
        do {
            // Save data to temporary file
            try videoData.write(to: tempFileURL)
            
            // Use the existing StorageUploader to handle the upload
            let remoteURL = try await StorageUploader.uploadIfNeeded(pinId: pinId, localURL: tempFileURL)
            
            // Clean up temporary file
            try? FileManager.default.removeItem(at: tempFileURL)
            
            // Return the uploaded URL
            return URL(string: remoteURL)!
        } catch {
            // Clean up temporary file in case of error
            try? FileManager.default.removeItem(at: tempFileURL)
            throw error
        }
    }

    // MARK: - Add MainActor observation for progress
    @MainActor
    func updateProgressOnMainActor(_ progress: Double) {
        self.uploadProgress = progress
    }
    
    // Set up progress observer for upload progress updates
    func setupProgressObservation() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProgressUpdateNotification),
            name: .uploadProgressUpdatedMainActor,
            object: nil
        )
    }
    
    @objc private func handleProgressUpdateNotification(_ notification: Notification) {
        guard let progress = notification.userInfo?["progress"] as? Double else { return }
        Task { @MainActor in
            self.uploadProgress = progress
        }
    }
}

// MARK: - Location Manager Delegate

@MainActor
extension MapViewModel: CLLocationManagerDelegate {
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            print("[MapViewModel] Delegate: Authorization status changed to: \(status.rawValue)")
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                print("[MapViewModel] Delegate: Authorized.")
                self.isLocationAuthorized = true
                if self.shouldCenterAfterAuthorization {
                    // Special handling for when we need to center after auth
                    Task {
                        do {
                            try await self.forceLocationPermissionCheck()
                        } catch {
                            print("[MapViewModel] Error during force location check from delegate: \(error)")
                        }
                    }
                }
            case .denied, .restricted:
                print("[MapViewModel] Delegate: Denied.")
                self.isLocationAuthorized = false
                self.isLimitedFunctionalityDueToLocationDenial = true
                
                // Only show error message if user actively requested location
                if self.isRequestingLocation {
                    self.showError("Location permission is required for this feature. Please enable in Settings.")
                }
                self.isRequestingLocation = false
            case .notDetermined:
                print("[MapViewModel] Delegate: Not Determined.")
                self.isLocationAuthorized = false
            @unknown default:
                print("[MapViewModel] Delegate: Unknown authorization status.")
                self.isLocationAuthorized = false
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            self.isRequestingLocation = false
            
            // Store most accurate location
            if self.userLocation == nil || 
               self.userLocation!.horizontalAccuracy > location.horizontalAccuracy {
                self.userLocation = location
                
                // Post notification for async waiting operations
                NotificationCenter.default.post(name: Notification.Name("LocationUpdated"), object: nil)
                print("[MapViewModel] Delegate: Location updated: (\(location.coordinate.latitude.truncated()), \(location.coordinate.longitude.truncated()))")
                
                // Center map if this is first location fix
                if self.mapRegion == nil || self.region.center.latitude == 40.7128 {
                    // Only auto-center on first fix or if map is at default
                    print("[MapViewModel] First location fix or map is at a default. Centering on user: (\(location.coordinate.latitude.truncated()), \(location.coordinate.longitude.truncated()))")
                    self.region = MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                    self.mapRegion = self.region
                    print("[MapViewModel] Set initial map region to user location: (\(location.coordinate.latitude.truncated()), \(location.coordinate.longitude.truncated())), span: \(self.region.span.latitudeDelta)")
                    print("[MapViewModel] Posted LocationUpdated notification")
                }
                
                // Process any pending pin coordinates
                if let pendingCoord = self.pendingCoordinate {
                    self.initiatePinDropVerification(at: pendingCoord)
                    self.pendingCoordinate = nil
                }
                
                // If action was waiting for location
                if self.shouldCenterAfterAuthorization {
                    self.centerOnUserLocation()
                    self.shouldCenterAfterAuthorization = false
                }
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Handle location errors gracefully
        let errorCode = (error as NSError).code
        let errorDescription = error.localizedDescription
        
        print("[MapViewModel] Location error \(errorCode): \(errorDescription)")
        
        Task { @MainActor in
            // Don't show alerts for common location errors unless user explicitly requested location
            if self.isRequestingLocation {
                // Only show errors to user when they explicitly requested location
                var message = "Unable to determine your location"
                
                // Provide more helpful messages for specific errors
                if errorCode == CLError.denied.rawValue {
                    message = "Location permission was denied. Please enable it in Settings."
                } else if errorCode == CLError.network.rawValue {
                    message = "Network error. Please check your connection and try again."
                } else if errorCode == CLError.locationUnknown.rawValue {
                    // This is common and temporary - don't alert user unless they explicitly requested
                    message = "Your location is temporarily unavailable. Please try again later."
                }
                
                if errorCode != CLError.locationUnknown.rawValue {
                    // Don't show alerts for temporary unknown location errors
                    self.showError(message)
                }
            }
            
            // For location unknown errors, which are temporary, try again after a short delay
            if (error as NSError).code == CLError.locationUnknown.rawValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    if self?.isRequestingLocation == true {
                        // Only retry if still requesting
                        self?.locationManager.requestLocation()
                    }
                }
            }
            
            self.isRequestingLocation = false
        }
    }
}

// MARK: - Error Handling Extensions

// Add this helper extension for user-friendly error messages
extension Error {
    var userFriendlyMessage: String {
        let nsError = self as NSError
        
        // Handle network errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return "No internet connection. Please check your connection and try again."
            case NSURLErrorTimedOut:
                return "Connection timed out. Please try again later."
            case NSURLErrorNetworkConnectionLost:
                return "Network connection was lost. Please try again."
            default:
                return "Network error. Please check your connection and try again."
            }
        }
        
        // Handle Firebase errors
        if nsError.domain.contains("Firebase") {
            // Auth errors
            if nsError.domain.contains("Auth") {
                switch nsError.code {
                case 17005:
                    return "Email address is already in use. Please use another email."
                case 17008:
                    return "Incorrect email or password. Please try again."
                case 17009:
                    return "Too many failed login attempts. Please try again later."
                case 17011:
                    return "Your account has been disabled. Please contact support."
                case 17026:
                    return "Password is too weak. Please use a stronger password."
                default:
                    return "Authentication error. Please try again."
                }
            }
            
            // Storage errors
            if nsError.domain.contains("Storage") {
                switch nsError.code {
                case -13000:
                    return "Video upload failed. Please try again."
                case -13010:
                    return "Not authorized to upload videos. Please sign in."
                default:
                    return "Storage error. Please try again."
                }
            }
            
            // Firestore errors
            if nsError.domain.contains("Firestore") {
                switch nsError.code {
                case 13:
                    return "Server is unavailable. Please try again later."
                case 7:
                    return "Network error. Please check your connection."
                case 16:
                    return "Not authorized to perform this action."
                default:
                    return "Database error. Please try again."
                }
            }
        }
        
        // Handle video-specific errors
        if nsError.domain.contains("AVFoundation") || nsError.domain.contains("Photos") {
            return "Video could not be processed. Please try another video."
        }
        
        // General permissions errors
        if nsError.domain.contains("Photos") && (nsError.code == 3 || nsError.code == 4) {
            return "Photo library access denied. Please allow access in Settings."
        }
        
        // Location errors
        if nsError.domain == "CLLocationManager" {
            return "Location services error. Please check your location permissions."
        }
        
        // Default error message for unhandled errors
        return self.localizedDescription
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let videoUploadProgressUpdated = Notification.Name("videoUploadProgressUpdated")
    static let uploadProgressUpdatedMainActor = Notification.Name("uploadProgressUpdatedMainActor")
}

// Class to safely hold StorageUploadTask
class StorageTaskHolder: @unchecked Sendable {
    var task: StorageUploadTask?
    
    init(task: StorageUploadTask) {
        self.task = task
    }
}

// Class to safely hold progress values across actor boundaries
class ProgressHolder: @unchecked Sendable {
    var progress: Double = 0
}

// MARK: - Add MainActor observation for progress
extension MapViewModel {
    // Safe method to update progress on main actor
    @objc private func updateProgressOnMainActor(_ notification: Notification) {
        guard let progress = notification.userInfo?["progress"] as? Double else { return }
        self.uploadProgress = progress
    }
}

enum LocationError: Error {
    case servicesDisabled
    case permissionDenied
    case unknown
}
