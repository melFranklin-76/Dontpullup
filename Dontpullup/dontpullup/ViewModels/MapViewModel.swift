import SwiftUI
import MapKit
import CoreLocation
import PhotosUI
import AVKit
import UniformTypeIdentifiers
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Network
import Foundation
import OSLog
import Combine

// Remove specific imports - types should be available within the module

// MARK: - Logger Setup

private let logger = Logger(subsystem: "com.dontpullup.app", category: "MapViewModel")
private let actorLogger = Logger(subsystem: "com.dontpullup.app", category: "VideoCompressor")
private let locationLogger = Logger(subsystem: "com.dontpullup.app", category: "LocationManager")
private let cacheLogger = Logger(subsystem: "com.dontpullup.app", category: "CacheManager")

// Add conditional logging extensions to disable trace and debug logs in release builds
#if DEBUG
extension Logger {
    func releaseTrace(_ message: String) {
        trace("\(message)")
    }
    
    func releaseDebug(_ message: String) {
        debug("\(message)")
    }
}
#else
extension Logger {
    func releaseTrace(_ message: String) {
        // No-op in release builds
    }
    
    func releaseDebug(_ message: String) {
        // No-op in release builds
    }
}
#endif

// Move the StorageError extension to file scope, before the MapViewModel class
private extension StorageError {
    var isPermissionError: Bool {
        switch self {
        case .unauthorized, .unauthenticated:
            return true
        default:
            return false
        }
    }
}

enum MapConstants {
    static let pinDropLimitMeters: CLLocationDistance = 200 * 0.3048 // 200 feet in meters
    
    // Pre-calculate the degrees for the span
    static let mapSpanDegrees: CLLocationDegrees = pinDropLimitMeters / 111000 * 2.5 
    
    static let defaultSpan = MKCoordinateSpan(
        latitudeDelta: mapSpanDegrees, // Use pre-calculated value
        longitudeDelta: mapSpanDegrees // Use pre-calculated value
    )
    
    static let minSpan = MKCoordinateSpan(
        latitudeDelta: mapSpanDegrees * 0.8,
        longitudeDelta: mapSpanDegrees * 0.8
    )
}

// MARK: - Video Compressor Actor

actor VideoCompressor {
    // Main compression function
    func compressVideo(at url: URL) async throws -> URL {
        actorLogger.info("Actor: Starting video compression...")
        
        let asset = AVAsset(url: url)
        guard FileManager.default.fileExists(atPath: url.path), (try await asset.loadTracks(withMediaType: .video)).count > 0 else {
            throw NSError(domain: "VideoCompression", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid video file or no video track found"])
        }
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        try? FileManager.default.removeItem(at: outputURL)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
            throw NSError(domain: "VideoCompression", code: -3, userInfo: [NSLocalizedDescriptionKey: "Could not create export session"])
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        let duration = try await asset.load(.duration)
        if duration.seconds > 180 {
            exportSession.timeRange = CMTimeRangeMake(start: .zero, duration: CMTime(seconds: 180, preferredTimescale: 600))
        }
        
        actorLogger.info("Actor: Starting export...")
        // Start export with an empty completion handler to avoid capture issues
        exportSession.exportAsynchronously {}

        // Monitor the export status in a separate Task within the actor
        return try await withCheckedThrowingContinuation { continuation in
            Task { // This monitoring Task runs on the VideoCompressor actor
                while true {
                    // Check status directly on the actor - safe
                    let currentStatus = exportSession.status
                    // print("Actor: Monitoring export status: \(currentStatus.rawValue)") // Optional debug log

                    if currentStatus == .completed {
                        guard let confirmedOutputURL = exportSession.outputURL else {
                            continuation.resume(throwing: NSError(domain: "VideoCompression", code: -8, userInfo: [NSLocalizedDescriptionKey: "Output URL nil after completion"]))
                            return // Exit task
                        }
                        do {
                             let compressedSize = try FileManager.default.attributesOfItem(atPath: confirmedOutputURL.path)[.size] as? Int64 ?? 0
                             let originalSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
                            if compressedSize >= originalSize && originalSize > 0 {
                                try? FileManager.default.removeItem(at: confirmedOutputURL)
                                continuation.resume(returning: url)
                            } else {
                                continuation.resume(returning: confirmedOutputURL)
                            }
                        } catch {
                             continuation.resume(throwing: error)
                        }
                        return // Exit task & while loop
                    } else if currentStatus == .failed || currentStatus == .cancelled {
                        let error = exportSession.error ?? NSError(domain: "VideoCompression", code: -10, userInfo: [NSLocalizedDescriptionKey: "Export failed/cancelled without specific error"])
                        continuation.resume(throwing: error)
                        return // Exit task & while loop
                    } else if currentStatus == .waiting || currentStatus == .exporting {
                        // Still in progress, yield/sleep briefly before checking again
                         try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds delay
                    } else { // Unknown or other status
                        continuation.resume(throwing: NSError(domain: "VideoCompression", code: -7, userInfo: [NSLocalizedDescriptionKey: "Export unknown status: \(currentStatus.rawValue)"]))
                        return // Exit task & while loop
                    }
                }
            }
        }
    }
}

@MainActor
class MapViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var pins: [Pin] = []
    @Published var filteredPins: [Pin] = []
    @Published var selectedFilters: Set<IncidentType> = []
    @Published var mapType: MKMapType = .standard
    @Published var mapRegion: MKCoordinateRegion?
    @Published var isEditMode = false
    @Published var showingIncidentPicker = false
    @Published var showingHelp = false
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var alertMessage: String?
    @Published var showAlert = false
    @Published private(set) var isListenerActive = false
    @Published var showingOnlyMyPins = false
    
    // MARK: - Internal Properties
    var pendingCoordinate: CLLocationCoordinate2D?
    var currentIncidentType: IncidentType?
    
    // MARK: - Zoom Subjects (for communication with Coordinator)
    let zoomInSubject = PassthroughSubject<Void, Never>()
    let zoomOutSubject = PassthroughSubject<Void, Never>()
    
    // MARK: - Private Properties
    private let locationManager: CLLocationManager
    private var uploadTasks: [StorageUploadTask] = []
    private let MAX_PIN_DISTANCE: CLLocationDistance = 61 // 200 feet in meters
    private let CLOSE_ZOOM_DELTA: CLLocationDegrees = 0.001 // Approximately 200-300 feet view
    private var isUploadInProgress = false
    private var uploadQueue: [(videoURL: URL, coordinate: CLLocationCoordinate2D, incidentType: IncidentType)] = []
    private let maxRetries = 3
    private var currentRetryCount = 0
    private let retryDelay: TimeInterval = 2.0 // Base delay in seconds
    private let cache = NSCache<NSString, NSData>()
    private let fileManager = FileManager.default
    private var offlineListener: ListenerRegistration?
    private var networkMonitor: NWPathMonitor?
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    private let videoCompressor = VideoCompressor() // Instance of the actor
    
    // Subject to pass location updates from delegate to main actor - REMOVED (kept commented for history)
    // private let locationUpdateSubject = PassthroughSubject<CLLocation, Never>()
    private var cancellables: Set<AnyCancellable> = []
    // private var locationSubscriptionCancellable: AnyCancellable? // REMOVED Dedicated property (kept commented for history)
    
    // Add a new property to track if initial region is set
    private var hasSetInitialRegion = false
    
    // MARK: - Initialization
    override init() {
        logger.releaseTrace("MapViewModel init() - START")
        // Initialize location manager before super.init()
        locationManager = CLLocationManager()
        
        // Configure cache with size limits
        cacheLogger.releaseTrace("Configuring NSCache")
        cache.countLimit = 50 // Maximum number of items
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit
        
        super.init()
        
        setupLocationManager()
        
        setupFirestoreListener() // Call directly
        
        loadCachedData()
        
        // Add observers for app state changes
        logger.releaseTrace("Adding App state observers")
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        setupNetworkMonitoring() // Keep network monitoring for offline/online status UI
        
        // Subscribe to location updates and store manually (State before deletion attempt)
        // let locationSubscription = subscribeToLocationUpdates() 
        // cancellables.insert(locationSubscription)
        // Note: We will remove this and the function below as part of the refactor.
        
        logger.releaseTrace("MapViewModel init() - END")
    }
    
    deinit {
        networkMonitor?.cancel()
        uploadTasks.forEach { $0.cancel() }
        NotificationCenter.default.removeObserver(self)
        // locationUpdateSubject.send(completion: .finished) // No longer exists
        cancellables.forEach { $0.cancel() } // Cancel subscriptions
        logger.info("MapViewModel deinit complete")
    }
    
    @objc private func handleAppBackground() {
        // Request background time for uploads
        if !uploadQueue.isEmpty || isUploadInProgress {
            let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "ProcessUploadQueue") { [backgroundTask = UIBackgroundTaskIdentifier.invalid] in
                // End the task if the background task expires
                if backgroundTask != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTask)
                }
            }
            
            if backgroundTask != .invalid {
                // Continue processing upload queue
                processUploadQueue()
                
                // End the task when done
                if backgroundTask != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTask)
                }
            }
        }
    }
    
    @objc private func handleAppForeground() {
        // Resume any paused uploads
        if !uploadQueue.isEmpty {
            processUploadQueue()
        }
    }
    
    private func processUploadQueue() {
        guard !uploadQueue.isEmpty else { return }
        
        // If already uploading, just return - the next item will be processed after current upload finishes
        guard !isUploadInProgress else { return }
        
        let nextUpload = uploadQueue.removeFirst()
        
        Task {
            do {
                isUploadInProgress = true
                isUploading = true
                uploadProgress = 0.01
                
                pendingCoordinate = nextUpload.coordinate
                currentIncidentType = nextUpload.incidentType
                
                try await processAndUploadVideo(from: nextUpload.videoURL)
                
                // Reset states after successful upload
                isUploadInProgress = false
                isUploading = false
                uploadProgress = 0
                pendingCoordinate = nil
                currentIncidentType = nil
                
                // Process next item in queue if any
                if !uploadQueue.isEmpty {
                    processUploadQueue()
                }
            } catch {
                handleUploadError(error, videoURL: nextUpload.videoURL, coordinate: nextUpload.coordinate, incidentType: nextUpload.incidentType)
            }
        }
    }
    
    private func handleUploadError(_ error: Error, videoURL: URL, coordinate: CLLocationCoordinate2D, incidentType: IncidentType) {
        if currentRetryCount < maxRetries {
            // Exponential backoff
            let delay = retryDelay * pow(2.0, Double(currentRetryCount))
            currentRetryCount += 1
            
            // Add back to queue with delay
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.uploadQueue.insert((videoURL: videoURL, coordinate: coordinate, incidentType: incidentType), at: 0)
                self.isUploadInProgress = false
                self.isUploading = false
                self.uploadProgress = 0
                self.processUploadQueue()
            }
        } else {
            // Max retries reached
            showError("Upload failed after multiple attempts: \(error.localizedDescription)")
            currentRetryCount = 0
            isUploadInProgress = false
            isUploading = false
            uploadProgress = 0
            
            // Save failed upload for later retry
            saveFailedUpload(videoURL: videoURL, coordinate: coordinate, incidentType: incidentType)
            
            // Process next in queue
            if !uploadQueue.isEmpty {
                processUploadQueue()
            }
        }
    }
    
    private func saveFailedUpload(videoURL: URL, coordinate: CLLocationCoordinate2D, incidentType: IncidentType) {
        // Save to UserDefaults or local storage for later retry
        let failedUpload = [
            "videoPath": videoURL.path,
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude,
            "type": incidentType.rawValue,
            "timestamp": Date().timeIntervalSince1970 // Add timestamp for sorting
        ] as [String : Any]
        
        var failedUploads = UserDefaults.standard.array(forKey: "FailedUploads") as? [[String: Any]] ?? []
        failedUploads.append(failedUpload)
        UserDefaults.standard.set(failedUploads, forKey: "FailedUploads")
        
        // Update UI with a user-friendly message
        Task { @MainActor in
            self.alertMessage = "Your upload was saved and can be retried when you have a better connection. Check 'My Pins' to retry."
            self.showAlert = true
        }
    }
    
    private func retryFailedUploads() {
        guard let failedUploads = UserDefaults.standard.array(forKey: "FailedUploads") as? [[String: Any]] else { return }
        
        for upload in failedUploads {
            guard let videoPath = upload["videoPath"] as? String,
                  let latitude = upload["latitude"] as? Double,
                  let longitude = upload["longitude"] as? Double,
                  let typeRaw = upload["type"] as? String,
                  let type = IncidentType(rawValue: typeRaw) else { continue }
            
            let videoURL = URL(fileURLWithPath: videoPath)
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            
            uploadQueue.append((videoURL: videoURL, coordinate: coordinate, incidentType: type))
        }
        
        // Clear failed uploads
        UserDefaults.standard.removeObject(forKey: "FailedUploads")
        
        // Start processing queue
        if !isUploadInProgress {
            processUploadQueue()
        }
    }
    
    // MARK: - Private Methods
    private func setupLocationManager() {
        locationLogger.trace("setupLocationManager() - START")
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update location only if moved by 10 meters
        locationManager.allowsBackgroundLocationUpdates = false
        
        // Request location permissions
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        default:
            break
        }
        locationLogger.trace("setupLocationManager() - END")
    }
    
    // MARK: - Public Methods
    func toggleMapType() {
        // Skip satellite mode since the style files aren't properly included
        // This prevents the "Failed to locate resource named satellite@3x.styl" errors
        switch mapType {
        case .standard:
            mapType = .hybrid // Skip satellite and go directly to hybrid
        case .hybrid:
            mapType = .mutedStandard
        case .mutedStandard, .satelliteFlyover, .hybridFlyover, .satellite:
            mapType = .standard
        @unknown default:
            mapType = .standard
        }
    }
    
    func centerOnUserLocation() {
        // Use the instance property instead of the deprecated static method
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            return
        
        case .restricted, .denied:
            showError("Location access is required to center on your location")
            return
        
        case .authorizedWhenInUse, .authorizedAlways:
            // Continue with location check
            break
        
        @unknown default:
            return
        }
        
        // Now check for actual location
        if let userLocation = locationManager.location {
            let tightZoomSpan = MKCoordinateSpan(
                latitudeDelta: MapConstants.mapSpanDegrees * 0.3, // ~200-ft window
                longitudeDelta: MapConstants.mapSpanDegrees * 0.3
            )
            let region = MKCoordinateRegion(
                center: userLocation.coordinate,
                span: tightZoomSpan
            )
            mapRegion = region
            hasSetInitialRegion = true
            print("Centered on user location")
        } else {
            // Try to get location after delay as fallback
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                if let delayedLocation = self.locationManager.location {
                    let region = MKCoordinateRegion(
                        center: delayedLocation.coordinate,
                        span: MKCoordinateSpan(
                            latitudeDelta: MapConstants.mapSpanDegrees * 0.3,
                            longitudeDelta: MapConstants.mapSpanDegrees * 0.3
                        )
                    )
                    self.mapRegion = region
                    self.hasSetInitialRegion = true
                } else {
                    // Use default location if all else fails
                    self.mapRegion = MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                        span: MapConstants.defaultSpan
                    )
                    self.hasSetInitialRegion = true
                    self.showError("Could not get your location")
                }
            }
        }
    }
    
    func toggleEditMode() {
        print("Toggling edit mode from \(isEditMode) to \(!isEditMode)")
        isEditMode.toggle()
        
        // Clear selection if turning off edit mode
        if !isEditMode {
            // If we were editing and turned it off, make sure we update the pins display
            updateFilteredPins()
        }
    }
    
    func toggleFilter(_ type: IncidentType) {
        print("Toggling filter for \(type.title)")
        if selectedFilters.contains(type) {
            selectedFilters.remove(type)
        } else {
            selectedFilters.insert(type)
        }
        updateFilteredPins()
    }
    
    func toggleMyPinsFilter() {
        print("Toggling my pins filter")
        showingOnlyMyPins.toggle()
        updateFilteredPins()
    }
    
    func updateFilteredPins() {
        // Step 1: Apply incident type filters if any are selected
        var tempFilteredPins = pins
        if !selectedFilters.isEmpty {
            tempFilteredPins = pins.filter { pin in
                selectedFilters.contains(pin.incidentType)
            }
        }
        
        // Step 2: Apply device filter if enabled
        if showingOnlyMyPins {
            guard let currentUserID = Auth.auth().currentUser?.uid else {
                filteredPins = [] // No user logged in, show no pins
                return
            }
            
            tempFilteredPins = tempFilteredPins.filter { pin in
                return pin.userId == currentUserID
            }
        }
        
        // Update the filtered pins
        filteredPins = tempFilteredPins
    }
    
    nonisolated func showError(_ message: String) {
        Task { @MainActor in
            self.alertMessage = message
            self.showAlert = true
        }
    }
    
    // MARK: - Video Processing Methods
    private func uploadVideo(_ videoURL: URL, to storageRef: StorageReference) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let metadata = StorageMetadata()
            metadata.contentType = "video/mp4"
            metadata.customMetadata = [
                "userId": Auth.auth().currentUser?.uid ?? "",
                "timestamp": "\(Date().timeIntervalSince1970)",
                "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            ]
            
            let uploadTask = storageRef.putFile(from: videoURL, metadata: metadata)
            uploadTasks.append(uploadTask)
            
            // Ensure upload state is visible
            Task { @MainActor in
                self.isUploading = true
                self.uploadProgress = 0.01 // Show initial progress
            }
            
            // Progress handler on main thread
            let progressHandle = uploadTask.observe(.progress) { [weak self] snapshot in
                guard let progress = snapshot.progress else { return }
                Task { @MainActor in
                    guard let self = self else { return }
                    // Only update if we're still uploading
                    if self.isUploading {
                        let newProgress = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                        // Ensure progress never goes backwards
                        if newProgress > self.uploadProgress {
                            self.uploadProgress = newProgress
                        }
                        print("Upload progress: \(self.uploadProgress)")
                    }
                }
            }
            
            // Success handler
            uploadTask.observe(.success) { [weak self] _ in
                Task {
                    // Ensure observers are removed *before* getting URL / resuming
                    await MainActor.run {
                        self?.uploadTasks.removeAll { $0 === uploadTask }
                    }
                    uploadTask.removeObserver(withHandle: progressHandle)
                    
                    // Introduce a small delay to allow GTMSessionFetcher to potentially settle
                    try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds
                    
                    do {
                        let downloadURL = try await storageRef.downloadURL()
                        
                        await MainActor.run {
                            if let self = self, self.isUploading {
                                self.uploadProgress = 1.0
                            }
                        }
                        
                        continuation.resume(returning: downloadURL.absoluteString)
                    } catch {
                        await MainActor.run {
                            self?.isUploading = false
                            self?.uploadProgress = 0
                        }
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            // Failure handler
            uploadTask.observe(.failure) { [weak self] snapshot in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.isUploading = false
                    self.uploadProgress = 0
                    
                    if let error = snapshot.error {
                        if let storageError = error as? StorageError,
                           storageError.isPermissionError {
                            // Attempt to refresh authentication
                            if let user = Auth.auth().currentUser {
                                do {
                                    let _ = try await user.getIDToken(forcingRefresh: true)
                                    // Explicitly cancel the failed task before retrying
                                    uploadTask.cancel() 
                                    self.retryUpload(videoURL: videoURL, continuation: continuation)
                                } catch {
                                    self.showError("Authentication failed: \(error.localizedDescription)")
                                    continuation.resume(throwing: error)
                                }
                            } else {
                                let error = NSError(
                                    domain: "VideoUpload",
                                    code: -3,
                                    userInfo: [NSLocalizedDescriptionKey: "Please sign in to upload videos."]
                                )
                                self.showError(error.localizedDescription)
                                continuation.resume(throwing: error)
                            }
                        } else {
                            // Replace technical error with user-friendly message
                            let userMessage: String
                            if let nsError = error as NSError? {
                                switch nsError.domain {
                                case "FIRStorageErrorDomain":
                                    if nsError.code == -13010 { // Network error
                                        userMessage = "Network connection issue. Please check your internet and try again."
                                    } else if nsError.code == -13040 { // Invalid token
                                        userMessage = "Your session has expired. Please sign in again."
                                    } else {
                                        userMessage = "Unable to upload video. Please try again later."
                                    }
                                case "NSURLErrorDomain":
                                    userMessage = "Network connection issue. Please check your internet and try again."
                                default:
                                    userMessage = "Unable to upload video. Please try again later."
                                }
                            } else {
                                userMessage = "Upload failed. Please try again."
                            }
                            self.showError(userMessage)
                            continuation.resume(throwing: error)
                        }
                    }
                    
                    self.uploadTasks.removeAll { $0 === uploadTask }
                    uploadTask.removeObserver(withHandle: progressHandle)
                }
            }
        }
    }
    
    private func retryUpload(videoURL: URL, continuation: CheckedContinuation<String, Error>) {
        Task {
            do {
                guard let currentUserId = Auth.auth().currentUser?.uid else {
                    throw NSError(domain: "VideoUpload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
                }
                
                let timestamp = Int(Date().timeIntervalSince1970)
                let filename = "video_\(UUID().uuidString)_\(timestamp)_\(currentUserId).mp4"
                let storageRef = Storage.storage().reference().child("videos/\(filename)")
                
                let downloadURL = try await uploadVideo(videoURL, to: storageRef)
                continuation.resume(returning: downloadURL)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func processAndUploadVideo(from videoURL: URL) async throws {
        print("Starting video processing...")
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            let error = NSError(domain: "VideoUpload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
            print("Authentication error: \(error)")
            throw error
        }
        
        guard let coordinate = pendingCoordinate,
              let incidentType = currentIncidentType else {
            let error = NSError(domain: "VideoUpload", code: -2, userInfo: [NSLocalizedDescriptionKey: "Missing location or incident type"])
            print("Missing data error: \(error)")
            throw error
        }
        
        await MainActor.run {
            isUploading = true
            uploadProgress = 0
        }
        
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "video_\(UUID().uuidString)_\(timestamp)_\(currentUserId)_\(deviceId).mp4"
        let storageRef = Storage.storage().reference().child("videos/\(filename)")
        
        print("Processing video for upload (calling actor)...")
        // Call the actor to handle compression
        let compressedURL = try await videoCompressor.compressVideo(at: videoURL)
        print("Video compression complete (returned from actor)")
        
        do {
            let downloadURL = try await uploadVideo(compressedURL, to: storageRef)
            print("Upload successful, creating Firestore document...")
            
            let pinId = UUID().uuidString
            let pin = Pin(
                id: pinId,
                coordinate: coordinate,
                incidentType: incidentType,
                videoURL: downloadURL,
                userId: currentUserId
            )
            
            // Create the document data
            let pinData: [String: Any] = [
                "latitude": pin.coordinate.latitude,
                "longitude": pin.coordinate.longitude,
                "type": pin.incidentType.firestoreType,
                "videoURL": pin.videoURL,
                "timestamp": FieldValue.serverTimestamp(),
                "userID": pin.userId,
                "deviceID": deviceId
            ]
            
            print("Attempting to create Firestore document with ID: \(pinId)")
            
            do {
                try await FirebaseManager.shared.firestore().collection("pins").document(pinId).setData(pinData)
                print("Firestore document created successfully")
                
                await MainActor.run {
                    self.pins.append(pin)
                    self.updateFilteredPins()
                    self.isUploading = false
                    self.uploadProgress = 0
                    self.pendingCoordinate = nil
                    self.currentIncidentType = nil
                }
                
                // Cleanup files
                try? FileManager.default.removeItem(at: compressedURL)
                if compressedURL != videoURL {
                    try? FileManager.default.removeItem(at: videoURL)
                }
            } catch let firestoreError {
                print("Firestore document creation failed: \(firestoreError)")
                // Try to delete the uploaded video since document creation failed
                try? await storageRef.delete()
                throw firestoreError
            }
        } catch let uploadError {
            print("Error during upload process: \(uploadError)")
            await MainActor.run {
                isUploading = false
                uploadProgress = 0
                showError("Upload failed: \(uploadError.localizedDescription)")
            }
            // Cleanup on error
            try? FileManager.default.removeItem(at: compressedURL)
            if compressedURL != videoURL {
                try? FileManager.default.removeItem(at: videoURL)
            }
            throw uploadError
        }
    }
    
    private func observePins() {
        logger.info("observePins() - Setting up Firestore pins listener...")
        
        // Only remove the existing listener if it exists
        if offlineListener != nil {
            logger.debug("Removing existing Firestore listener before re-attaching.")
            offlineListener?.remove()
            offlineListener = nil // Ensure it's nil after removal
        }
        
        // Indicate listener is potentially inactive during setup
        isListenerActive = false 
        
        let db = FirebaseManager.shared.firestore()
        logger.debug("Creating Firestore listener...")
        offlineListener = db.collection("pins")
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                guard let self = self else { 
                    logger.warning("Firestore listener callback: self is nil")
                    return 
                }
                
                if let error = error {
                    logger.error("Firestore listener error: \(error.localizedDescription)")
                    if (error as NSError).domain == "FIRFirestoreErrorDomain" && (error as NSError).code == 8 { 
                         logger.warning("Network connection lost. Using cached data.")
                         self.showError("Network connection lost. Using cached data.")
                    } else {
                         self.showError("Failed to fetch pins: \(error.localizedDescription)")
                    }
                    return
                }
                
                guard let snapshot = snapshot else {
                    logger.error("Firestore listener: Snapshot is nil")
                    self.showError("No data available. Please check your connection.")
                    return
                }
                
                let source = snapshot.metadata.isFromCache ? "cache" : "server"
                logger.info("Firestore listener: Loading pins from \(source). Document changes: \(snapshot.documentChanges.count)")
                
                Task {
                     logger.trace("Firestore listener: Starting background task to process snapshot...")
                     await self.processSnapshot(snapshot)
                     logger.trace("Firestore listener: Background task finished processing snapshot.")
                }

                // Successfully received data (or error handled), listener is considered active
                // Place this inside the callback to ensure it runs after attachment attempt
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if !self.isListenerActive {
                        self.isListenerActive = true
                        logger.info("Firestore listener is now active.")
                    }
                }
            }
        
        // Check if listener setup returned a valid registration
        if offlineListener != nil {
             logger.info("Firestore pins listener setup request potentially successful (registration obtained). Awaiting first callback.")
             // We now set isListenerActive = true *inside* the callback
        } else {
             logger.error("Firestore pins listener setup failed immediately (nil registration).")
             // Ensure isListenerActive remains false if setup failed instantly
             isListenerActive = false
        }
    }
    
    private func processSnapshot(_ snapshot: QuerySnapshot) async {
        logger.trace("processSnapshot() - START")
        do {
            logger.debug("Processing \(snapshot.documents.count) documents in snapshot...")
            let processedPins = try await withThrowingTaskGroup(of: Pin?.self) { group in
                for document in snapshot.documents {
                    group.addTask { // These tasks run concurrently
                         // Ensure processDocument is non-blocking if possible
                        return try? await self.processDocument(document)
                    }
                }
                
                var collectedPins: [Pin] = []
                for try await pin in group {
                    if let pin = pin {
                        collectedPins.append(pin)
                    }
                }
                logger.debug("Finished processing task group, collected \(collectedPins.count) valid pins.")
                return collectedPins
            }
            
            logger.trace("processSnapshot() - Updating main thread state...")
            await MainActor.run {
                logger.trace("processSnapshot() @MainActor - START update")
                self.pins = processedPins
                self.updateFilteredPins() // Ensure this is efficient
                self.cachePins(processedPins)
                logger.trace("processSnapshot() @MainActor - END update")
            }
            logger.trace("processSnapshot() - Finished main thread update.")
        } catch {
            logger.error("processSnapshot() - Failed to process data: \(error.localizedDescription)")
            await MainActor.run {
                self.showError("Failed to process data: \(error.localizedDescription)")
            }
        }
        logger.trace("processSnapshot() - END")
    }
    
    private func processDocument(_ document: QueryDocumentSnapshot) async throws -> Pin? {
        logger.trace("processDocument() - START for ID: \(document.documentID)")
        let data = document.data()
        
        guard let latitude = data["latitude"] as? Double,
              let longitude = data["longitude"] as? Double,
              let typeString = data["type"] as? String,
              let videoURL = data["videoURL"] as? String,
              let userId = data["userID"] as? String else {
            logger.warning("Invalid document data skipped: \(document.documentID)")
            return nil
        }
        
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        let incidentType: IncidentType
        switch typeString {
        case "Verbal": incidentType = .verbal
        case "Physical": incidentType = .physical
        case "911": incidentType = .emergency
        default:
            print("Invalid incident type: \(typeString)")
            return nil
        }
        
        let pin = Pin(
            id: document.documentID,
            coordinate: coordinate,
            incidentType: incidentType,
            videoURL: videoURL,
            userId: userId
        )
        logger.trace("processDocument() - END for ID: \(document.documentID)")
        return pin
    }
    
    private func loadCachedData() {
        cacheLogger.trace("loadCachedData() - START")
        if let cachedData = cache.object(forKey: "pins" as NSString) as? Data,
           let decodedPins = try? JSONDecoder().decode([Pin].self, from: cachedData) { // Renamed to avoid conflict
            logger.info("Loaded \(decodedPins.count) pins from NSCache")
            self.pins = decodedPins
            updateFilteredPins()
        } else if let cachedData = UserDefaults.standard.data(forKey: "CachedPins"),
                  let decodedPins = try? JSONDecoder().decode([CachedPin].self, from: cachedData) { // Check UserDefaults
            logger.info("Loaded \(decodedPins.count) pins from UserDefaults cache")
            self.pins = decodedPins.map { $0.toPin() }
            updateFilteredPins()
        } else {
            cacheLogger.info("No cached pins found in NSCache or UserDefaults.")
        }
        cacheLogger.trace("loadCachedData() - END")
    }
    
    private func cachePins(_ pinsToCache: [Pin]) { // Renamed parameter
        cacheLogger.trace("cachePins() - START")
        let cachedPins = pinsToCache.map { CachedPin(from: $0) }
        if let encodedPins = try? JSONEncoder().encode(cachedPins) {
            // Prioritize NSCache for faster access
            cache.setObject(encodedPins as NSData, forKey: "pins" as NSString)
            cacheLogger.debug("Stored \(pinsToCache.count) pins in NSCache")
            // Also save to UserDefaults for persistence
            UserDefaults.standard.set(encodedPins, forKey: "CachedPins")
            cacheLogger.debug("Stored \(pinsToCache.count) pins in UserDefaults")
        } else {
            cacheLogger.error("Failed to encode pins for caching.")
        }
        cacheLogger.trace("cachePins() - END")
    }
    
    // MARK: - Cache Management
    private func setupCacheDirectory() {
        do {
            var cacheDir = getCacheDirectory()
            if !fileManager.fileExists(atPath: cacheDir.path) {
                try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
                print("Cache directory created successfully at: \(cacheDir.path)")
            }
            
            // Set directory attributes to prevent FileProvider bookmarking
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try cacheDir.setResourceValues(resourceValues)
            
        } catch {
            print("Error setting up cache directory: \(error.localizedDescription)")
            // Create a backup cache directory in case of failure
            let backupCacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("VideoCache_Backup")
            do {
                try fileManager.createDirectory(at: backupCacheDir, withIntermediateDirectories: true, attributes: nil)
                print("Backup cache directory created at: \(backupCacheDir.path)")
            } catch {
                print("Critical error: Failed to create backup cache directory: \(error.localizedDescription)")
            }
        }
        cleanupOldCache()
    }
    
    private func cleanupOldCache() {
        Task.detached {
            let cacheDir = await self.getCacheDirectory()
            let resourceKeys: Set<URLResourceKey> = [.creationDateKey, .totalFileAllocatedSizeKey, .isExcludedFromBackupKey]
            
            guard let fileURLs = try? FileManager.default.contentsOfDirectory(at: cacheDir,
                                                                            includingPropertiesForKeys: Array(resourceKeys),
                                                                            options: .skipsHiddenFiles) else {
                return
            }
            
            let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            
            // Determine adaptive cache size based on device free space
            let maxCacheSize: UInt64
            do {
                let fileSystemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
                let freeSpace = fileSystemAttributes[.systemFreeSize] as? UInt64 ?? 0
                
                // Limit cache to smaller of: 5% of free space or 500MB
                let fivePercentOfFreeSpace = UInt64(Double(freeSpace) * 0.05)
                maxCacheSize = min(fivePercentOfFreeSpace, 500 * 1024 * 1024)
            } catch {
                // Fallback to 100MB if unable to determine free space
                maxCacheSize = 100 * 1024 * 1024
            }
            
            var totalSize: UInt64 = 0
            
            for fileURL in fileURLs {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                      let creationDate = resourceValues.creationDate,
                      let fileSize = resourceValues.totalFileAllocatedSize else {
                    continue
                }
                
                totalSize += UInt64(fileSize)
                
                // Remove files that are:
                // 1. Older than a week
                // 2. Not excluded from backup
                // 3. If we're over the cache size limit
                if creationDate < oneWeekAgo || 
                   !(resourceValues.isExcludedFromBackup ?? false) ||
                   totalSize > maxCacheSize {
                    try? FileManager.default.removeItem(at: fileURL)
                    totalSize -= UInt64(fileSize)
                }
            }
        }
    }
    
    private func getCacheDirectory() -> URL {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        var cacheDir = paths[0].appendingPathComponent("VideoCache", isDirectory: true)
        
        do {
            if !fileManager.fileExists(atPath: cacheDir.path) {
                try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
                
                // Set directory attributes
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                try cacheDir.setResourceValues(resourceValues)
            }
        } catch {
            print("Error creating cache directory: \(error.localizedDescription)")
        }
        
        return cacheDir
    }
    
    private func getVideoCacheURL(for videoURL: String) -> URL {
        let cacheDir = getCacheDirectory()
        let fileName = videoURL.replacingOccurrences(of: "/", with: "_")
        return cacheDir.appendingPathComponent(fileName)
    }
    
    func cacheVideo(from url: URL, key: String) async throws {
        print("Attempting to cache video for key: \(key)")
        
        let maxRetries = 3
        var currentRetry = 0
        
        while currentRetry < maxRetries {
            do {
                // Create a safe filename by hashing the key
                let safeFilename = String(abs(key.hashValue)) + ".mp4"
                
                let fileManager = FileManager.default
                let cacheDirectory = try fileManager.url(for: .cachesDirectory, 
                                                       in: .userDomainMask, 
                                                       appropriateFor: nil, 
                                                       create: true)
                let fileURL = cacheDirectory.appendingPathComponent(safeFilename)
                
                // Check if video is already cached
                if fileManager.fileExists(atPath: fileURL.path) {
                    print("Video already exists in cache at: \(fileURL.path)")
                    return
                }
                
                print("Downloading video to cache...")
                
                // Create a URLSession with a longer timeout and better configuration
                let configuration = URLSessionConfiguration.default
                configuration.timeoutIntervalForRequest = 300 // 5 minutes
                configuration.timeoutIntervalForResource = 300 // 5 minutes
                configuration.waitsForConnectivity = true
                configuration.allowsExpensiveNetworkAccess = true
                configuration.allowsConstrainedNetworkAccess = true
                let session = URLSession(configuration: configuration)
                
                let (downloadedURL, response) = try await session.download(from: url)
                
                // Handle different types of responses
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200...299:
                        // Success case - proceed with caching
                        if fileManager.fileExists(atPath: fileURL.path) {
                            try fileManager.removeItem(at: fileURL)
                        }
                        try fileManager.moveItem(at: downloadedURL, to: fileURL)
                        
                        print("Successfully cached video at: \(fileURL)")
                        
                        // Store in memory cache
                        if let data = try? Data(contentsOf: fileURL) {
                            cache.setObject(data as NSData, forKey: key as NSString)
                            print("Video also stored in memory cache")
                        }
                        return
                    case 401, 403:
                        throw NSError(domain: "VideoCache",
                                    code: httpResponse.statusCode,
                                    userInfo: [NSLocalizedDescriptionKey: "Authentication error"])
                    case 404:
                        throw NSError(domain: "VideoCache",
                                    code: httpResponse.statusCode,
                                    userInfo: [NSLocalizedDescriptionKey: "Video not found"])
                    default:
                        throw NSError(domain: "VideoCache",
                                    code: httpResponse.statusCode,
                                    userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
                    }
                }
                
            } catch {
                currentRetry += 1
                if currentRetry >= maxRetries {
                    print("Failed to cache video after \(maxRetries) attempts: \(error.localizedDescription)")
                    throw error
                } else {
                    print("Retry \(currentRetry) of \(maxRetries) for caching video")
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(currentRetry)) * 1_000_000_000))
                    continue
                }
            }
        }
    }
    
    func getCachedVideo(for key: String) -> Data? {
        print("Attempting to retrieve cached video for key: \(key)")
        
        // Check memory cache first
        if let cachedData = cache.object(forKey: key as NSString) {
            print("Found video in memory cache")
            return cachedData as Data
        }
        
        // Check disk cache
        let safeFilename = String(abs(key.hashValue)) + ".mp4"
        let cacheDirectory = try? FileManager.default.url(for: .cachesDirectory,
                                                        in: .userDomainMask,
                                                        appropriateFor: nil,
                                                        create: false)
        
        guard let fileURL = cacheDirectory?.appendingPathComponent(safeFilename),
              let data = try? Data(contentsOf: fileURL) else {
            print("Video not found in cache")
            return nil
        }
        
        print("Found video in disk cache")
        // Update memory cache
        cache.setObject(data as NSData, forKey: key as NSString)
        return data
    }
    
    // Add CachedPin struct for serialization
    private struct CachedPin: Codable {
        let id: String
        let latitude: Double
        let longitude: Double
        let incidentType: String
        let videoURL: String
        let userId: String
        
        init(from pin: Pin) {
            self.id = pin.id
            self.latitude = pin.coordinate.latitude
            self.longitude = pin.coordinate.longitude
            self.incidentType = pin.incidentType.rawValue
            self.videoURL = pin.videoURL
            self.userId = pin.userId
        }
        
        func toPin() -> Pin {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            let type = IncidentType(rawValue: incidentType) ?? .verbal
            return Pin(id: id, coordinate: coordinate, incidentType: type, videoURL: videoURL, userId: userId)
        }
    }
    
    private func setupFirestoreListener() {
        logger.info("setupFirestoreListener() - Setting up Firestore listener...")
        // REMOVE manual retry logic - let Firebase SDK handle it
        /*
        let maxRetries = 3
        var retryCount = 0
        
        func setupListener() {
            // ... existing listener setup ...
        }
        setupListener()
        */
        
        // Direct listener setup without manual retry loop
        if offlineListener != nil {
            logger.debug("Removing existing listener before attaching new one.")
            offlineListener?.remove()
            offlineListener = nil
        }
        
        offlineListener = FirebaseManager.shared.firestore().collection("pins")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    // Log error but don't manually retry here
                    logger.error("Firestore listener error: \(error.localizedDescription)")
                    // Optionally show a generic error or rely on cache
                     if (error as NSError).domain == "FIRFirestoreErrorDomain" && (error as NSError).code == 8 { 
                         logger.warning("Network connection lost. Using cached data.")
                         // Maybe show transient UI indicator?
                    } else {
                         self.showError("Failed to sync pins: \(error.localizedDescription)")
                    }
                    return // Let SDK handle reconnection attempts
                }
                
                guard let snapshot = snapshot else {
                    logger.error("Firestore listener: Snapshot is nil")
                    return
                }
                
                // Process snapshot normally
                Task {
                    await self.processSnapshot(snapshot)
                }
            }
        
        if offlineListener != nil {
            logger.info("Firestore listener attached successfully.")
        } else {
            logger.error("Firestore listener attachment failed immediately.")
        }
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            Task { @MainActor in
                guard let self = self else { return }
                if !isConnected {
                    self.showError("Network connection lost. Using cached data.")
                    // Don't necessarily reload cache here, listener might still provide it
                } else {
                    // Network is back, Firebase listener should reconnect automatically.
                    // Triggering manual retry might still be useful?
                    // self.retryFailedUploads() // Keep this maybe?
                     logger.info("Network connection restored.")
                     // Let's NOT manually restart the listener here, trust the SDK
                     // self.observePins() 
                }
            }
        }
        networkMonitor?.start(queue: networkQueue)
        
        // REMOVE periodic connectivity check Task
        /*
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                if !Task.isCancelled {
                    checkConnectivity()
                }
            }
        }
        */
    }
    
    @MainActor
    func signOut() {
        // First clean up all resources
        uploadTasks.forEach { $0.cancel() }
        uploadQueue.removeAll()
        isUploadInProgress = false
        isUploading = false
        
        // Clear local data
        pins.removeAll()
        filteredPins.removeAll()
        selectedFilters.removeAll()
        pendingCoordinate = nil
        currentIncidentType = nil
        
        // Clear cached data
        UserDefaults.standard.removeObject(forKey: "CachedPins")
        UserDefaults.standard.removeObject(forKey: "FailedUploads")
        
        // Sign out from Firebase - requires try
        do {
            try Auth.auth().signOut()
            print("Signed out successfully")
        } catch {
            print("Error signing out: \(error.localizedDescription)")
            showError("Failed to sign out: \(error.localizedDescription)")
        }
    }
    
    func deletePin(_ pin: Pin) async throws {
        print("Starting delete pin process for: \(pin.id)")
        // First check if user can edit this pin
        guard await userCanEditPin(pin) else {
            print("User is not authorized to delete this pin: \(pin.id)")
            throw NSError(
                domain: "PinDeletion",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "You can only delete pins that you created on this device"]
            )
        }
        
        // Double check authentication
        guard let currentUserId = Auth.auth().currentUser?.uid,
              currentUserId == pin.userId else {
            print("Authentication error - current user: \(Auth.auth().currentUser?.uid ?? "nil"), pin user: \(pin.userId)")
            throw NSError(
                domain: "PinDeletion",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Authentication error"]
            )
        }
        
        // If authorized, proceed with deletion
        print("User authorized to delete pin: \(pin.id)")
        
        // First try deleting from Firestore, then handle video storage
        do {
            try await FirebaseManager.shared.firestore().collection("pins").document(pin.id).delete()
            print("Successfully deleted pin from Firestore: \(pin.id)")
            
            // After Firestore success, try video deletion (but don't fail if it doesn't work)
            if let videoURL = URL(string: pin.videoURL) {
                do {
                    let storageRef = Storage.storage().reference(forURL: videoURL.absoluteString)
                    try await storageRef.delete()
                    print("Successfully deleted video for pin: \(pin.id)")
                } catch {
                    // Just log video deletion error but don't prevent pin deletion
                    print("Warning: Could not delete video, but pin was deleted: \(error.localizedDescription)")
                }
            }
            
            // Update local arrays on main thread
            await MainActor.run {
                print("Updating UI after pin deletion: \(pin.id)")
                self.pins.removeAll { $0.id == pin.id }
                self.filteredPins.removeAll { $0.id == pin.id }
                self.updateFilteredPins()
            }
        } catch {
            print("Failed to delete pin from Firestore: \(error.localizedDescription)")
            throw error
        }
    }
    
    func userCanEditPin(_ pin: Pin) async -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("Cannot edit pin: User not authenticated")
            return false
        }
        
        // Check if the pin belongs to the current user
        let canEdit = pin.userId == currentUserId
        if !canEdit {
            print("Cannot edit pin: Pin belongs to different user")
        }
        return canEdit
    }
    
    nonisolated func isFilterActive(_ type: IncidentType) async -> Bool {
        await Task { @MainActor in
            selectedFilters.contains(type)
        }.value
    }
    
    @MainActor
    func dropPin(for type: IncidentType) {
        // Request fresh location to verify pin placement
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            showError("Location access is required to verify pin placement")
            return
        }
        
        // Request a single location update
        locationManager.requestLocation()
        
        guard let currentLocation = locationManager.location else {
            showError("Unable to determine your location")
            return
        }
        
        guard let coordinate = pendingCoordinate else {
            showError("No location selected")
            return
        }
        
        let pinLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distance = currentLocation.distance(from: pinLocation)
        
        guard distance <= MAX_PIN_DISTANCE else {
            showError("You can only drop pins within 200 feet of your location")
            return
        }
        
        currentIncidentType = type
        
        // Present photo picker on the main thread
        Task { @MainActor in
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            
            switch status {
            case .authorized, .limited:
                var config = PHPickerConfiguration(photoLibrary: .shared())
                config.filter = .videos
                config.selectionLimit = 1
                config.preferredAssetRepresentationMode = .current
                
                let picker = PHPickerViewController(configuration: config)
                picker.delegate = self
                
                // Find the top-most view controller
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    // Dismiss the current view controller first
                    if let presentedVC = rootViewController.presentedViewController {
                        presentedVC.dismiss(animated: true) {
                            // Present the photo picker after dismissal
                            rootViewController.present(picker, animated: true) {
                                // Set this to false only after the picker is presented
                                self.showingIncidentPicker = false
                            }
                        }
                    } else {
                        rootViewController.present(picker, animated: true) {
                            // Set this to false only after the picker is presented
                            self.showingIncidentPicker = false
                        }
                    }
                } else {
                    showError("Could not present video picker")
                    currentIncidentType = nil
                    pendingCoordinate = nil
                    showingIncidentPicker = false
                }
                
            case .denied, .restricted:
                showError("Please allow access to your photo library in Settings to upload videos")
                currentIncidentType = nil
                pendingCoordinate = nil
                showingIncidentPicker = false
                
            case .notDetermined:
                showError("Photo library access is required to upload videos")
                currentIncidentType = nil
                pendingCoordinate = nil
                showingIncidentPicker = false
                
            @unknown default:
                showError("Unknown photo library access status")
                currentIncidentType = nil
                pendingCoordinate = nil
                showingIncidentPicker = false
            }
        }
    }
    
    @MainActor
    private func cleanupTemporaryFiles() {
        let tempDirectory = FileManager.default.temporaryDirectory
        do {
            let tempFiles = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            for file in tempFiles where file.lastPathComponent.contains("compressed_") {
                try? FileManager.default.removeItem(at: file)
            }
        } catch {
            print("Failed to cleanup temporary files: \(error.localizedDescription)")
        }
    }
    
    private func loadVideo(from provider: NSItemProvider) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let originalURL = url else {
                    continuation.resume(throwing: NSError(
                        domain: "VideoLoad",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid video file"]
                    ))
                    return
                }
                
                do {
                    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let tempFileName = "\(UUID().uuidString)_temp.mov"
                    let tempURL = documentsDirectory.appendingPathComponent(tempFileName)
                    
                    if FileManager.default.fileExists(atPath: tempURL.path) {
                        try FileManager.default.removeItem(at: tempURL)
                    }
                    try FileManager.default.copyItem(at: originalURL, to: tempURL)
                    continuation.resume(returning: tempURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func checkVideoDuration(_ url: URL) async throws {
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration)
        let durationInSeconds = CMTimeGetSeconds(duration)
        
        if durationInSeconds > 180 {
            throw NSError(
                domain: "VideoUpload",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Video must be 3 minutes or shorter. Please trim your video or choose a shorter one."]
            )
        }
    }
    
    // MARK: - Helper Methods (subscribeToLocationUpdates removed)

    // Add a new method to safely get current location
    func getCurrentLocation() async -> CLLocation? {
        return locationManager.location
    }

    // Expose retry functionality to UI
    @MainActor
    func hasFailedUploads() -> Bool {
        let failedUploads = UserDefaults.standard.array(forKey: "FailedUploads") as? [[String: Any]] ?? []
        return !failedUploads.isEmpty
    }

    @MainActor
    func getFailedUploadsCount() -> Int {
        let failedUploads = UserDefaults.standard.array(forKey: "FailedUploads") as? [[String: Any]] ?? []
        return failedUploads.count
    }

    // Public method for UI to call for retrying uploads
    @MainActor
    func retryAllFailedUploads() {
        guard hasFailedUploads() else { return }
        
        retryFailedUploads()
        
        // Provide user feedback
        alertMessage = "Retrying your saved uploads..."
        showAlert = true
    }

    @MainActor
    func reportPin(_ pin: Pin) {
        Task {
            // No longer require authentication
            let db = FirebaseManager.shared.firestore()
            do {
                print("Attempting to report pin \(pin.id)")
                let reportData: [String: Any] = [
                    "pinId": pin.id,
                    "reason": "general",
                    "timestamp": FieldValue.serverTimestamp()
                ]
                try await db.collection("reports").addDocument(data: reportData)
                self.alertMessage = "Thank you for reporting this video. Our moderators will review it."
                self.showAlert = true
            } catch {
                print("Error reporting pin: \(error.localizedDescription)")
                self.alertMessage = "Failed to report video: \(error.localizedDescription)"
                self.showAlert = true
            }
        }
    }

    @MainActor
    func reportPin(_ pin: Pin, email: String, reason: String, completion: @escaping (Bool) -> Void) {
        // Firestore() doesn't throw, so no try needed
        let firestore = FirebaseManager.shared.firestore()
        
        let report: [String: Any] = [
            "pinId": pin.id,
            "reporterEmail": email,
            "reason": reason,
            "timestamp": FieldValue.serverTimestamp(),
            "status": "pending"
        ]
        
        firestore.collection("reports").addDocument(data: report) { error in
            if let error = error {
                print("Error submitting report: \(error.localizedDescription)")
                completion(false)
            } else {
                print("Report submitted successfully")
                completion(true)
            }
        }
    }

    func zoomIn() {
        zoomInSubject.send()
    }
    
    func zoomOut() {
        zoomOutSubject.send()
    }

}

// MARK: - Location Manager Delegate
extension MapViewModel: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.startUpdatingLocation()
                if !hasSetInitialRegion {
                    centerOnUserLocation() // Remove await since centerOnUserLocation is not async
                }
            default:
                break
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            // Only update region if we haven't set initial region
            if !hasSetInitialRegion {
                let region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MapConstants.defaultSpan
                )
                mapRegion = region
                hasSetInitialRegion = true
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code != .locationUnknown {
            Task { @MainActor in
                locationLogger.error("locationManager didFailWithError: \(error.localizedDescription)")
                self.showError("Location error: \(error.localizedDescription)")
            }
        } else {
            locationLogger.warning("locationManager didFailWithError: CLError.locationUnknown (ignoring)")
        }
    }
}

// MARK: - PHPicker Delegate
extension MapViewModel: PHPickerViewControllerDelegate {
    nonisolated func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        // Capture necessary values before the Task
        let firstResult = results.first
        let itemProvider = firstResult?.itemProvider
        
        Task { @MainActor in
            defer {
                if let presentingVC = picker.presentingViewController {
                    presentingVC.dismiss(animated: true)
                }
            }
            
            guard let provider = itemProvider else {
                pendingCoordinate = nil
                currentIncidentType = nil
                isUploading = false
                return
            }
            
            guard provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
                showError("Please select a video")
                pendingCoordinate = nil
                currentIncidentType = nil
                isUploading = false
                return
            }
            
            guard let coordinate = pendingCoordinate,
                  let incidentType = currentIncidentType else {
                showError("Missing location or incident type")
                isUploading = false
                return
            }
            
            do {
                let videoURL = try await loadVideo(from: provider)
                // Add to queue first, then process
                uploadQueue.append((videoURL: videoURL, coordinate: coordinate, incidentType: incidentType))
                
                // Only start processing if not already in progress
                if !isUploadInProgress {
                    processUploadQueue()
                }
            } catch {
                showError("Failed to process video: \(error.localizedDescription)")
                isUploading = false
                uploadProgress = 0
                pendingCoordinate = nil
                currentIncidentType = nil
            }
        }
    }
}

// Add extension for MKMapType to handle cycling through types
private extension MKMapType {
    var next: MKMapType {
        switch self {
        case .standard:
            return .satellite
        case .satellite:
            return .hybrid
        case .hybrid:
            return .mutedStandard
        default:
            return .standard
        }
    }
}


