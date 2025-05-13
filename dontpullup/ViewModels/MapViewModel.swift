import SwiftUI
import MapKit
@preconcurrency import CoreLocation
import FirebaseFirestore
import FirebaseAuth
import AVKit
@preconcurrency import UIKit
import FirebaseStorage
@preconcurrency import Dispatch

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
    
    // MARK: - Zoom helpers
    func zoomIn() {
        print("[MapViewModel] Zoom in requested")
        var newRegion = self.region // Start with the current actual region

        var latDelta = newRegion.span.latitudeDelta * 0.5
        var lonDelta = newRegion.span.longitudeDelta * 0.5

        latDelta = max(latDelta, minSpanDelta)
        lonDelta = max(lonDelta, minSpanDelta)

        newRegion.span = MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        
        print("[MapViewModel] Setting zoom region from \(self.region.span.latitudeDelta) to \(newRegion.span.latitudeDelta)")
        // Important: Set both region and mapRegion for proper updates
        self.region = newRegion
        
        // Force UI update by explicitly setting a new region
        DispatchQueue.main.async {
            self.mapRegion = MKCoordinateRegion(
                center: newRegion.center,
                span: newRegion.span
            )
        }
    }
    
    func zoomOut() {
        print("[MapViewModel] Zoom out requested")
        var newRegion = self.region // Start with the current actual region

        var latDelta = newRegion.span.latitudeDelta * 2
        var lonDelta = newRegion.span.longitudeDelta * 2

        latDelta = min(latDelta, maxSpanDelta)
        lonDelta = min(lonDelta, maxSpanDelta)

        newRegion.span = MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        
        print("[MapViewModel] Setting zoom region from \(self.region.span.latitudeDelta) to \(newRegion.span.latitudeDelta)")
        // Important: Set both region and mapRegion for proper updates
        self.region = newRegion
        
        // Force UI update by explicitly setting a new region
        DispatchQueue.main.async {
            self.mapRegion = MKCoordinateRegion(
                center: newRegion.center,
                span: newRegion.span
            )
        }
    }
    
    @MainActor
    func centerOnUserLocation() {
        guard let userLocation = userLocation else {
            showAlert = true
            alertMessage = "Unable to determine your location"
            return
        }
        
        print("[MapViewModel] Centering on user location: \(userLocation.coordinate)")
        
        let newCenteredRegion = MKCoordinateRegion(
            center: userLocation.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.0011, longitudeDelta: 0.0011)
        )
        
        // Update both region and mapRegion for consistent state
        self.region = newCenteredRegion
        
        // Force UI update by explicitly setting a new region
        self.mapRegion = MKCoordinateRegion(
            center: userLocation.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.0011, longitudeDelta: 0.0011)
        )
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
    
    private struct TimeoutError: Error {}
    
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
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        return pin.userId == currentUserId
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
    func showError(_ message: String) {
        Task { @MainActor in
            // Add message to queue and try to show
            alertQueue.append(message)
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
            // Only clear if not in the process of handling another operation
            if !uploadProgress.isZero && uploadProgress < 1.0 {
                print("[MapViewModel] Not clearing pending data - upload in progress: \(uploadProgress)")
                return
            }
            
            print("[MapViewModel] Clearing pending operation data")
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
    func forceLocationPermissionCheck() async {
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
            return
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
            Task { await forceLocationPermissionCheck() } 
        }
    }
    
    // MARK: - Pin Management
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
            videoURL: "",
            userId: currentUserId
        )
        
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
                await MainActor.run {
                    self.pins.append(newPin)
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
    init(authState: AuthState) { // Updated initializer
        self.authState = authState
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: .appDidBecomeActiveForLocationCheck,
            object: nil
        )
        print("[MapViewModel] Initialized and subscribed to appDidBecomeActiveForLocationCheck notification.")
        
        // Perform the initial CoreLocation status check off the main thread
        Task {
            await checkInitialLocationStatus()
        }
        
        loadPins()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .appDidBecomeActiveForLocationCheck, object: nil)
        print("[MapViewModel] Deinitialized and unsubscribed from appDidBecomeActiveForLocationCheck notification.")
    }
    
    @objc private func handleAppDidBecomeActive() {
        print("[MapViewModel] App active - NO automatic location check.")
        // Do nothing automatically - user must explicitly request location
    }
    
    private func loadPins() {
        print("[MapViewModel] Loading pins from Firestore")
        db.collection("pins").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("[MapViewModel] Error loading pins: \(error.localizedDescription)")
                self.showError("Failed to load pins: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("[MapViewModel] No pins found")
                return
            }
            
            print("[MapViewModel] Found \(documents.count) pins")
            
            Task { @MainActor in
                let loadedPins = documents.compactMap { document -> Pin? in
                    let data = document.data()
                    
                    guard let idString = data["id"] as? String,
                          let latitudeValue = data["latitude"] as? Double,
                          let longitudeValue = data["longitude"] as? Double,
                          let typeString = data["type"] as? String,
                          let userIdString = data["userId"] as? String else {
                        print("[MapViewModel] Invalid pin data in document \(document.documentID)")
                        return nil
                    }
                    
                    let coordinate = CLLocationCoordinate2D(latitude: latitudeValue, longitude: longitudeValue)
                    let videoURL = data["videoURL"] as? String ?? ""
                    
                    let incidentType = IncidentType.fromFirestoreType(typeString)
                    
                    return Pin(
                        id: idString,
                        coordinate: coordinate,
                        incidentType: incidentType,
                        videoURL: videoURL,
                        userId: userIdString
                    )
                }
                
                self.pins = loadedPins
                print("[MapViewModel] Successfully loaded \(loadedPins.count) pins")
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
                    Task { await self.forceLocationPermissionCheck() }
                }
            }
        }
    }
    
    func dropPinWithVideo(for incidentType: IncidentType, videoURL: URL) async throws {
        print("[MapViewModel] Starting video upload process...")
        guard let pendingCoordinate = pendingCoordinate,
              let currentUserId = Auth.auth().currentUser?.uid else {
            print("[MapViewModel] Missing coordinate or user ID")
            await MainActor.run {
                showAlert = true
                alertMessage = "Unable to drop pin. Please try again."
                showingIncidentPicker = false
            }
            throw NSError(domain: "MapViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing coordinate or user ID"])
        }
        
        print("[MapViewModel] Uploading video for incident type: \(incidentType.title) at \(pendingCoordinate.latitude), \(pendingCoordinate.longitude)")
        
        let pinId = UUID().uuidString
        print("[MapViewModel] Generated pin ID: \(pinId)")
        
        // Upload video to Firebase Storage
        let storageRef = Storage.storage().reference().child("videos/\(pinId).mp4")
        
        // Create metadata
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            print("[MapViewModel] Starting upload task...")
            
            // Start the upload task
            let uploadTask = storageRef.putFile(from: videoURL, metadata: metadata)
            
            // Store handles so we can remove them later
            var progressHandle: String?
            var successHandle: String?
            var failureHandle: String?
            
            // Monitor upload progress and handle completion
            progressHandle = uploadTask.observe(.progress) { snapshot in
                let completedUnitCount = snapshot.progress?.completedUnitCount ?? 0
                let totalUnitCount = snapshot.progress?.totalUnitCount ?? 1
                let percentComplete = Double(completedUnitCount) / Double(totalUnitCount) * 100
                print("[MapViewModel] Upload is \(percentComplete)% complete")
                
                Task { @MainActor in
                    self.uploadProgress = percentComplete / 100.0
                }
            }
            
            successHandle = uploadTask.observe(.success) { _ in
                print("[MapViewModel] Upload task completed successfully")
                
                // Clean up observers
                if let progressHandle = progressHandle {
                    uploadTask.removeObserver(withHandle: progressHandle)
                }
                if let failureHandle = failureHandle {
                    uploadTask.removeObserver(withHandle: failureHandle)
                }
                
                // Get download URL after successful upload
                storageRef.downloadURL { url, error in
                    if let error = error {
                        print("[MapViewModel] Failed to get download URL: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let downloadURL = url else {
                        print("[MapViewModel] Download URL is nil")
                        continuation.resume(throwing: NSError(domain: "StorageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"]))
                        return
                    }
                    
                    print("[MapViewModel] Got download URL: \(downloadURL.absoluteString)")
                    
                    // Create pin data
                    let pinData: [String: Any] = [
                        "id": pinId,
                        "latitude": pendingCoordinate.latitude,
                        "longitude": pendingCoordinate.longitude,
                        "type": incidentType.firestoreType,
                        "videoURL": downloadURL.absoluteString,
                        "userId": currentUserId,
                        "timestamp": FieldValue.serverTimestamp()
                    ]
                    
                    // Add pin to Firestore
                    let db = Firestore.firestore()
                    db.collection("pins").document(pinId).setData(pinData) { error in
                        if let error = error {
                            print("[MapViewModel] Failed to save pin to Firestore: \(error.localizedDescription)")
                            continuation.resume(throwing: error)
                        } else {
                            print("[MapViewModel] Successfully saved pin to Firestore")
                            
                            // Update local pins array
                            Task { @MainActor in
                                let newPin = Pin(
                                    id: pinId,
                                    coordinate: pendingCoordinate,
                                    incidentType: incidentType,
                                    videoURL: downloadURL.absoluteString,
                                    userId: currentUserId
                                )
                                
                                self.pins.append(newPin)
                                self.pendingCoordinate = nil
                                self.pendingVideoData = nil
                                self.uploadProgress = 0
                                self.showingIncidentPicker = false
                            }
                            
                            continuation.resume(returning: ())
                        }
                    }
                }
            }
            
            failureHandle = uploadTask.observe(.failure) { snapshot in
                print("[MapViewModel] Upload task failed")
                
                // Clean up observers
                if let progressHandle = progressHandle {
                    uploadTask.removeObserver(withHandle: progressHandle)
                }
                if let successHandle = successHandle {
                    uploadTask.removeObserver(withHandle: successHandle)
                }
                
                if let error = snapshot.error as? NSError {
                    print("[MapViewModel] Upload error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    print("[MapViewModel] Unknown upload error")
                    continuation.resume(throwing: NSError(domain: "StorageError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unknown upload error"]))
                }
            }
        }
    }
    
    func startReportFlow(at coord: CLLocationCoordinate2D) {
        reportDraft = PinDraft(coordinate: coord)
        reportStep = .type
    }
    
    @MainActor
    func upload(draft: PinDraft) async {
        // Check if user is anonymous AND trying to upload a video
        if authState.isAnonymous && draft.videoURL != nil {
            showError("Guests cannot upload videos.")
            reportStep = nil // Dismiss the report sheet
            // Potentially clear draft.videoURL or reset draft if needed
            // self.reportDraft.videoURL = nil 
            return
        }

        do {
            let pinId = UUID().uuidString
            let remoteURL = try await StorageUploader.uploadIfNeeded(
                                pinId: pinId, localURL: draft.videoURL)
            try await FirestorePins.addPin(id: pinId,
                                           coord: draft.coordinate,
                                           type: draft.incidentType,
                                           videoURL: remoteURL)
            pins.append(draft.makePin(id: pinId, remote: remoteURL))
            reportStep = nil                       // close sheet
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    // Enhanced zoom to user location function
    func zoomToUserTight() {
        guard let userLocation = userLocation else {
            showAlert = true
            alertMessage = "Unable to determine your location"
            return
        }
        
        // Zoom to roughly 200 foot radius for precise pin placement
        // 200 feet is approximately 61 meters
        let pinDropRadius = 200 * 0.3048 // Convert feet to meters
        
        // Calculate span to show roughly the pin drop radius
        // Approx conversion: 1 degree latitude = 111km (111,000m)
        let spanDelta = (pinDropRadius * 1.5) / 111000
        
        // Set region with tight zoom focused on user
        let newTightRegion = MKCoordinateRegion(
            center: userLocation.coordinate,
            span: MKCoordinateSpan(latitudeDelta: spanDelta, longitudeDelta: spanDelta)
        )
        self.region = newTightRegion      // Update the ViewModel's main region state
        self.mapRegion = newTightRegion   // Signal the MapView to update
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
    
    /// Checks if a given coordinate is within 200 feet of the user's current location
    /// - Parameter coordinate: The coordinate to check
    /// - Returns: Boolean indicating if coordinate is within range
    func isWithinPinDropRange(coordinate: CLLocationCoordinate2D) async -> Bool {
        guard let userLocation = await getCurrentLocation() else {
            return false
        }
        
        let pinLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distance = userLocation.distance(from: pinLocation)
        
        // 200 feet in meters (1 foot ≈ 0.3048 meters)
        let pinDropLimit = 200 * 0.3048
        
        return distance <= pinDropLimit
    }
    
    // Zoom constraints - aligned with MapViewConstants for consistency
    private let minSpanDelta: CLLocationDegrees = 0.00013  // Must match MapViewConstants.minSpan
    private let maxSpanDelta: CLLocationDegrees = 0.8      // Reasonable max zoom out, less than MapViewConstants.maxZoomDistance
    
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
                showError("Failed to save pin with video: \(error.localizedDescription)")
            }
        }
    }
    
    private func uploadVideoToStorage(videoData: Data, fileExtension: String) async throws -> URL {
        // Implementation of uploadVideoToStorage method
        // This method should return the URL of the uploaded video
        fatalError("Method not implemented")
    }
    
    private func savePinToFirestore(_ pin: Pin) async throws {
        // Implementation of savePinToFirestore method
        // This method should save the pin to Firestore
        fatalError("Method not implemented")
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
        processAlertQueue()
    }
}

// MARK: - CLLocationManagerDelegate
extension MapViewModel: CLLocationManagerDelegate {
    nonisolated
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Capture the status in the nonisolated context
        let status = manager.authorizationStatus
        
        // Process the status on the MainActor where UI updates happen
        Task {
            // Get location services enabled state off the main thread
            let servicesEnabled = await self.checkLocationServicesEnabled()
            
            await MainActor.run {
                print("[MapViewModel] Delegate: Authorization status changed to: \(status.rawValue)")
                self.isLocationServicesEnabled = servicesEnabled
                self.isLocationAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
                self.isRequestingLocation = false // No longer actively requesting permission itself

                if !self.isLocationServicesEnabled {
                    self.alertMessage = "Location services are disabled. Please enable them in Settings."
                    self.showAlert = true
                    return
                }

                switch status {
                case .authorizedWhenInUse, .authorizedAlways:
                    print("[MapViewModel] Delegate: Authorized.")
                    self.isLimitedFunctionalityDueToLocationDenial = false // Clear the flag
                    UserDefaults.standard.set(false, forKey: "userDeclinedLocationPermissions") // Clear user default
                    // NEVER automatically get location - wait for explicit requests
                    if self.shouldCenterAfterAuthorization {
                        self.centerOnUserLocation()
                        self.shouldCenterAfterAuthorization = false
                    }
                    if let coord = self.pendingCoordinate {
                        self.initiatePinDropVerification(at: coord)
                        self.pendingCoordinate = nil
                    }
                case .denied, .restricted:
                    print("[MapViewModel] Delegate: Denied or restricted.")
                    self.alertMessage = "Location access is required for core features. Please enable it in Settings."
                    self.showAlert = true
                    // Ensure userLocation is nil if access is denied to prevent using stale data
                    self.userLocation = nil 
                    self.isLimitedFunctionalityDueToLocationDenial = true // Set the flag
                    UserDefaults.standard.set(true, forKey: "userDeclinedLocationPermissions") // Set user default
                case .notDetermined:
                    print("[MapViewModel] Delegate: Status became .notDetermined. This shouldn't usually happen after an initial request.")
                @unknown default:
                    print("[MapViewModel] Delegate: Unknown authorization status: \(status.rawValue)")
                }

                // If we're not in live-tracking mode, stop updates after we get a fix
                if !self.isTrackingUserLocation {
                    self.locationManager.stopUpdatingLocation()
                }
            }
        }
    }
    
    nonisolated
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            // Store previous location to check if it's meaningfully different
            let previousLocation = self.userLocation
            
            // Update userLocation
            self.userLocation = location
            print("[MapViewModel] Delegate: Location updated: \(location.coordinate)")
            
            // Break down complex conditions into separate variables
            let isLatitudeNYC = self.region.center.latitude == 40.7128
            let isLongitudeNYC = self.region.center.longitude == -74.0060
            let isMapAtDefaultNYC = isLatitudeNYC && isLongitudeNYC
            
            let isLatitudeEquator = self.region.center.latitude == 0
            let isLongitudeEquator = self.region.center.longitude == 0
            let isMapAtDefaultEquator = isLatitudeEquator && isLongitudeEquator
            
            let isFirstLocationFix = previousLocation == nil
            let shouldUpdateRegionToUserLocation = isFirstLocationFix || isMapAtDefaultNYC || isMapAtDefaultEquator

            if shouldUpdateRegionToUserLocation {
                print("[MapViewModel] First location fix or map is at a default. Centering on user: \(location.coordinate)")
                // Use a span consistent with other user-centric views, e.g., from centerOnUserLocation or a sensible default.
                // For this example, using a span similar to the initial MapView span.
                let defaultUserSpan = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01) // A reasonable zoom level for user location
                let newRegion = MKCoordinateRegion(
                    center: location.coordinate,
                    span: defaultUserSpan 
                )
                self.region = newRegion      // Update the ViewModel's main region state
                self.mapRegion = newRegion   // Signal the MapView to update
                print("[MapViewModel] Set initial map region to user location: \(newRegion.center), span: \(newRegion.span.latitudeDelta)")
            }
            
            // Center map if explicitly requested after authorization
            if self.shouldCenterAfterAuthorization {
                self.centerOnUserLocation()
                self.shouldCenterAfterAuthorization = false
            }
            
            // Break down notification check into separate variables
            let isNewLocation = previousLocation == nil
            let hasMoved = previousLocation != nil && (previousLocation!.distance(from: location) > 1.0) // 1 meter threshold
            let shouldNotify = isNewLocation || hasMoved
            
            if shouldNotify {
                NotificationCenter.default.post(name: Notification.Name("LocationUpdated"), object: nil)
                print("[MapViewModel] Posted LocationUpdated notification")
            }
        }
    }
    
    nonisolated
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[MapViewModel] Delegate: Failed to get location: \(error.localizedDescription)")
        Task { @MainActor in
            self.isRequestingLocation = false
            // Optionally show an alert to the user
            // self.alertMessage = "Failed to get location: \(error.localizedDescription)"
            // self.showAlert = true
        }
    }
    
    // Add a helper method to access authorizationStatus safely in other parts of the code
    func getCurrentAuthorizationStatus() -> CLAuthorizationStatus {
        // Avoid touching the MainActor-isolated `locationManager` from the
        // non-isolated context by instantiating a fresh manager here.
        return CLLocationManager().authorizationStatus
    }
}

enum ReportStep: Int, Identifiable, CaseIterable {
    case type, video, confirm
    var id: Int { rawValue }
} 
