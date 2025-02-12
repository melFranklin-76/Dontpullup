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

@preconcurrency import PhotosUI

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
    static let pinDropLimit: CLLocationDistance = 200 * 0.3048 // 200 feet in meters
    static let defaultSpan = MKCoordinateSpan(
        latitudeDelta: pinDropLimit / 111000 * 2.5, // Convert meters to degrees with some padding
        longitudeDelta: pinDropLimit / 111000 * 2.5
    )
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
    
    // MARK: - Internal Properties
    var pendingCoordinate: CLLocationCoordinate2D?
    var currentIncidentType: IncidentType?
    
    // MARK: - Private Properties
    private let locationManager: CLLocationManager
    private var uploadTasks: [StorageUploadTask] = []
    private let MAX_PIN_DISTANCE: CLLocationDistance = 61 // 200 feet in meters
    private let CLOSE_ZOOM_DELTA: CLLocationDegrees = 0.001 // Approximately 200-300 feet view
    private var isUploadInProgress = false
    private var uploadQueue: [(URL, CLLocationCoordinate2D, IncidentType)] = []
    private let maxRetries = 3
    private var currentRetryCount = 0
    private let retryDelay: TimeInterval = 2.0 // Base delay in seconds
    private let cache = NSCache<NSString, NSData>()
    private let fileManager = FileManager.default
    private var offlineListener: ListenerRegistration?
    private var networkMonitor: NWPathMonitor?
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    // MARK: - Initialization
    override init() {
        // Initialize location manager before super.init()
        locationManager = CLLocationManager()
        
        // Configure cache with size limits
        cache.countLimit = 50 // Maximum number of items
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit
        
        super.init()
        
        // Configure location manager
        setupLocationManager()
        
        // Setup offline support and start observing pins
        setupOfflineSupport()
        observePins() // Explicitly call observePins
        
        // Replace the Timer with a proper async Task
        Task { @MainActor in
            while true {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                if !Task.isCancelled {
                    self.checkAndRestartListener()
                }
            }
        }
        
        // Load cached data if available
        loadCachedData()
        
        // Test storage access
        testStorageAccess()
        
        // Add observers for app state changes
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
        
        // Setup network monitoring
        setupNetworkMonitoring()
    }
    
    deinit {
        networkMonitor?.cancel()
        uploadTasks.forEach { $0.cancel() }
        NotificationCenter.default.removeObserver(self)
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
        
        let (videoURL, coordinate, incidentType) = uploadQueue.removeFirst()
        
        Task {
            do {
                isUploadInProgress = true
                isUploading = true
                uploadProgress = 0.01
                
                pendingCoordinate = coordinate
                currentIncidentType = incidentType
                
                try await processAndUploadVideo(from: videoURL)
                
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
                handleUploadError(error, videoURL: videoURL, coordinate: coordinate, incidentType: incidentType)
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
                self.uploadQueue.insert((videoURL, coordinate, incidentType), at: 0)
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
            "type": incidentType.rawValue
        ] as [String : Any]
        
        var failedUploads = UserDefaults.standard.array(forKey: "FailedUploads") as? [[String: Any]] ?? []
        failedUploads.append(failedUpload)
        UserDefaults.standard.set(failedUploads, forKey: "FailedUploads")
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
            
            uploadQueue.append((videoURL, coordinate, type))
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
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.allowsBackgroundLocationUpdates = false
        // Stop continuous updates
        locationManager.pausesLocationUpdatesAutomatically = true
        
        // Only check initial authorization status
        switch locationManager.authorizationStatus {
        case .notDetermined:
            print("Location authorization not determined, requesting...")
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            print("Location access denied or restricted")
            showError("Location access is required to use this app. Please enable it in Settings.")
        case .authorizedWhenInUse, .authorizedAlways:
            print("Location access authorized")
            // Only get initial location
            locationManager.requestLocation()
        @unknown default:
            print("Unknown location authorization status")
            showError("Unknown location authorization status")
        }
    }
    
    // MARK: - Public Methods
    func toggleMapType() {
        mapType = mapType.next
    }
    
    func centerOnUserLocation() {
        print("Attempting to center on user location")
        
        let authStatus = locationManager.authorizationStatus
        
        switch authStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Request a single location update
            locationManager.requestLocation()
        case .denied, .restricted:
            showError("Location access is required. Please enable it in Settings.")
        case .notDetermined:
            print("Location authorization not determined, requesting...")
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            showError("Unknown location authorization status")
        }
    }
    
    func toggleEditMode() {
        print("Toggling edit mode from \(isEditMode) to \(!isEditMode)")
        isEditMode.toggle()
    }
    
    func toggleFilter(_ type: IncidentType) {
        if selectedFilters.contains(type) {
            selectedFilters.remove(type)
        } else {
            selectedFilters.insert(type)
        }
        updateFilteredPins()
    }
    
    func updateFilteredPins() {
        // Simple direct filtering without any grouping or clustering
        filteredPins = selectedFilters.isEmpty ? pins : pins.filter { selectedFilters.contains($0.incidentType) }
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
                    
                    await MainActor.run {
                        self?.uploadTasks.removeAll { $0 === uploadTask }
                    }
                    uploadTask.removeObserver(withHandle: progressHandle)
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
                                    // Retry upload after token refresh
                                    self.retryUpload(videoURL: videoURL, continuation: continuation)
                                } catch {
                                    self.showError("Authentication failed: \(error.localizedDescription)")
                                    continuation.resume(throwing: error)
                                }
                            } else {
                                let error = NSError(
                                    domain: "VideoUpload",
                                    code: -3,
                                    userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in."]
                                )
                                self.showError(error.localizedDescription)
                                continuation.resume(throwing: error)
                            }
                        } else {
                            self.showError("Upload failed: \(error.localizedDescription)")
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
        
        print("Processing video for upload...")
        let compressedURL = try await compressVideo(at: videoURL)
        print("Video compression complete")
        
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
    
    @MainActor
    private func compressVideo(at url: URL) async throws -> URL {
        print("Starting video compression...")
        
        // Verify input video exists and is readable
        guard FileManager.default.fileExists(atPath: url.path),
              FileManager.default.isReadableFile(atPath: url.path) else {
            throw NSError(
                domain: "VideoCompression",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Input video file is not accessible"]
            )
        }
        
        let asset = AVAsset(url: url)
        
        // Verify asset is valid and has video track
        guard try await asset.load(.tracks).count > 0,
              try try await asset.loadTracks(withMediaType: .video).count > 0 else {
            throw NSError(
                domain: "VideoCompression",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid video file or no video track found"]
            )
        }
        
        // Create unique output path
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        // Remove any existing file at output path
        try? FileManager.default.removeItem(at: outputURL)
        
        // Create and configure export session
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetMediumQuality
        ) else {
            throw NSError(
                domain: "VideoCompression",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Could not create export session"]
            )
        }
        
        // Configure export session
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Set maximum duration if needed
        let duration = try await asset.load(.duration)
        if duration.seconds > 60 {
            exportSession.timeRange = CMTimeRangeMake(
                start: .zero,
                duration: CMTime(seconds: 60, preferredTimescale: 600)
            )
        }
        
        print("Compressing video...")
        
        // Use async/await for export operation
        try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    do {
                        // Verify output file exists
                        guard FileManager.default.fileExists(atPath: outputURL.path) else {
                            throw NSError(
                                domain: "VideoCompression",
                                code: -4,
                                userInfo: [NSLocalizedDescriptionKey: "Compressed file not found"]
                            )
                        }
                        
                        // Check if the compressed file is actually smaller
                        let compressedSize = try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64 ?? 0
                        let originalSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
                        
                        print("Original size: \(originalSize), Compressed size: \(compressedSize)")
                        
                        if compressedSize >= originalSize {
                            // If compression didn't help, use the original file
                            try? FileManager.default.removeItem(at: outputURL)
                            print("Using original file as compression did not reduce size")
                            continuation.resume(returning: url)
                        } else {
                            print("Using compressed file")
                            continuation.resume(returning: outputURL)
                        }
                    } catch {
                        print("Error checking file sizes: \(error)")
                        continuation.resume(throwing: error)
                    }
                    
                case .failed:
                    let error = exportSession.error ?? NSError(
                        domain: "VideoCompression",
                        code: -5,
                        userInfo: [NSLocalizedDescriptionKey: "Export failed with unknown error"]
                    )
                    print("Export failed: \(error)")
                    continuation.resume(throwing: error)
                    
                case .cancelled:
                    print("Export cancelled")
                    continuation.resume(throwing: NSError(
                        domain: "VideoCompression",
                        code: -6,
                        userInfo: [NSLocalizedDescriptionKey: "Export was cancelled"]
                    ))
                    
                default:
                    print("Export failed with status: \(exportSession.status.rawValue)")
                    continuation.resume(throwing: NSError(
                        domain: "VideoCompression",
                        code: -7,
                        userInfo: [NSLocalizedDescriptionKey: "Export failed with unknown status"]
                    ))
                }
            }
        }
    }
    
    private func observePins() {
        print("Setting up Firestore pins listener...")
        
        // Remove existing listener if any
        offlineListener?.remove()
        isListenerActive = false
        
        let db = FirebaseManager.shared.firestore()
        
        // Setup offline persistence with real-time updates
        offlineListener = db.collection("pins")
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Firestore error: \(error.localizedDescription)")
                    if (error as NSError).domain == "FIRFirestoreErrorDomain" && 
                        (error as NSError).code == 8 { // Unavailable error
                        // Network error - use cached data and notify user
                        self.showError("Network connection lost. Using cached data.")
                        return
                    }
                    self.showError("Failed to fetch pins: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot else {
                    self.showError("No data available. Please check your connection.")
                    return
                }
                
                // Check for metadata changes
                let source = snapshot.metadata.isFromCache ? "cache" : "server"
                print("Loading pins from \(source)")
                
                Task {
                    do {
                        // Process pins with immediate updates
                        let newPins = try await withThrowingTaskGroup(of: Pin?.self) { group in
                            for change in snapshot.documentChanges {
                                group.addTask {
                                    switch change.type {
                                    case .added, .modified:
                                        return try await self.processDocument(change.document)
                                    case .removed:
                                        // Handle removed pins
                                        await MainActor.run {
                                            self.pins.removeAll { $0.id == change.document.documentID }
                                            self.updateFilteredPins()
                                        }
                                        return nil
                                    }
                                }
                            }
                            
                            var processedPins: [Pin] = []
                            for try await pin in group {
                                if let pin = pin {
                                    processedPins.append(pin)
                                }
                            }
                            return processedPins
                        }
                        
                        await MainActor.run {
                            // Update pins array based on changes
                            for pin in newPins {
                                if let index = self.pins.firstIndex(where: { $0.id == pin.id }) {
                                    self.pins[index] = pin
                                } else {
                                    self.pins.append(pin)
                                }
                            }
                            self.updateFilteredPins()
                            self.cachePins(self.pins)
                        }
                        
                        self.isListenerActive = true
                    } catch {
                        await MainActor.run {
                            self.showError("Failed to process pins: \(error.localizedDescription)")
                        }
                    }
                }
            }
        
        print("Firestore pins listener setup complete")
    }
    
    private func processDocument(_ document: QueryDocumentSnapshot) async throws -> Pin? {
        let data = document.data()
        
        guard let latitude = data["latitude"] as? Double,
              let longitude = data["longitude"] as? Double,
              let typeString = data["type"] as? String,
              let videoURL = data["videoURL"] as? String,
              let userId = data["userID"] as? String else {
            print("Invalid document data: \(document.documentID)")
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
        
        // Cache video in background if online
        if let url = URL(string: videoURL) {
            Task.detached {
                do {
                    try await self.cacheVideo(from: url, key: videoURL)
                } catch {
                    print("Failed to cache video: \(error.localizedDescription)")
                }
            }
        }
        
        return Pin(
            id: document.documentID,
            coordinate: coordinate,
            incidentType: incidentType,
            videoURL: videoURL,
            userId: userId
        )
    }
    
    private func loadCachedData() {
        if let cachedData = cache.object(forKey: "pins" as NSString) as? Data,
           let pins = try? JSONDecoder().decode([Pin].self, from: cachedData) {
            self.pins = pins
            updateFilteredPins()
        }
    }
    
    private func cachePins(_ pins: [Pin]) {
        let cachedPins = pins.map { CachedPin(from: $0) }
        if let encodedPins = try? JSONEncoder().encode(cachedPins) {
            UserDefaults.standard.set(encodedPins, forKey: "CachedPins")
        }
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
            let maxCacheSize: UInt64 = 500 * 1024 * 1024 // 500MB
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
    
    private func setupOfflineSupport() {
        // Setup offline listener with retry logic
        setupFirestoreListener()
    }
    
    private func setupFirestoreListener() {
        let maxRetries = 3
        var retryCount = 0
        
        func setupListener() {
            offlineListener = FirebaseManager.shared.firestore().collection("pins")
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("Firestore error: \(error.localizedDescription)")
                        
                        if (error as NSError).domain == "FIRFirestoreErrorDomain" &&
                           (error as NSError).code == 8 { // Network error
                            if retryCount < maxRetries {
                                retryCount += 1
                                let delay = Double(retryCount) * 2.0 // Exponential backoff
                                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                    setupListener()
                                }
                            } else {
                                self.showError("Network connection lost. Using cached data.")
                                self.loadCachedData()
                            }
                        }
                        return
                    }
                    
                    retryCount = 0 // Reset retry count on successful connection
                    
                    guard let snapshot = snapshot else {
                        self.showError("No data available")
                        return
                    }
                    
                    Task {
                        await self.processSnapshot(snapshot)
                    }
                }
        }
        
        setupListener()
    }
    
    private func processSnapshot(_ snapshot: QuerySnapshot) async {
        do {
            let pins = try await withThrowingTaskGroup(of: Pin?.self) { group in
                for document in snapshot.documents {
                    group.addTask {
                        do {
                            return try await self.processDocument(document)
                        } catch {
                            print("Error processing document: \(error)")
                            return nil
                        }
                    }
                }
                
                var processedPins: [Pin] = []
                for try await pin in group {
                    if let pin = pin {
                        processedPins.append(pin)
                    }
                }
                return processedPins
            }
            
            await MainActor.run {
                self.pins = pins
                self.updateFilteredPins()
                self.cachePins(pins)
            }
        } catch {
            await MainActor.run {
                self.showError("Failed to process data: \(error.localizedDescription)")
            }
        }
    }
    
    private func checkAndRestartListener() {
        if !isListenerActive {
            print("Restarting Firestore listener...")
            observePins()
        }
    }
    
    // Helper function to test storage URLs
    private func testStorageAccess() {
        let storage = Storage.storage()
        let storageRef = storage.reference()
        
        // List all items in the videos folder
        let videosRef = storageRef.child("videos")
        
        Task {
            do {
                let result = try await videosRef.listAll()
                print("\n=== Storage Contents ===")
                print("Found \(result.items.count) items in storage")
                
                for item in result.items {
                    do {
                        let url = try await item.downloadURL()
                        print("\nFile: \(item.name)")
                        print("URL: \(url.absoluteString)")
                        print("Full path: \(item.fullPath)")
                        
                        // Get metadata
                        let metadata = try await item.getMetadata()
                        if let userId = metadata.customMetadata?["userId"] {
                            print("User ID: \(userId)")
                        }
                        print("Size: \(Double(metadata.size) / 1024 / 1024)MB")
                        print("Content Type: \(metadata.contentType ?? "unknown")")
                        print("Created: \(metadata.timeCreated ?? Date())")
                    } catch {
                        print("Error getting URL for \(item.name): \(error.localizedDescription)")
                    }
                }
                print("\n======================")
            } catch {
                print("Error listing files: \(error.localizedDescription)")
            }
        }
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            Task { @MainActor in
                if !isConnected {
                    self?.showError("Network connection lost. Using cached data.")
                    self?.loadCachedData()
                } else {
                    // Refresh data when connection is restored
                    self?.observePins()
                    // Retry any failed uploads
                    self?.retryFailedUploads()
                }
            }
        }
        networkMonitor?.start(queue: networkQueue)
        
        // Add periodic connectivity check
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                if !Task.isCancelled {
                    await checkConnectivity()
                }
            }
        }
    }
    
    @MainActor
    private func checkConnectivity() {
        guard let monitor = networkMonitor else { return }
        
        if monitor.currentPath.status == .satisfied {
            // Ensure Firestore listener is active
            if !isListenerActive {
                observePins()
            }
            
            // Retry any pending operations
            retryFailedUploads()
        }
    }
    
    private func handleNetworkError(_ error: Error) {
        if (error as NSError).domain == "NSURLErrorDomain" {
            // Handle specific network errors
            switch (error as NSError).code {
            case -1003: // Could not find host
                showError("Network connection issue. Please check your internet connection.")
            case -1009: // No internet connection
                showError("No internet connection. Using cached data.")
                loadCachedData()
            default:
                showError("Network error: \(error.localizedDescription)")
            }
        } else {
            showError("Error: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func signOut() {
        do {
            // Cancel any ongoing uploads
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
            
            // Sign out from Firebase
            try Auth.auth().signOut()
            
            print("Successfully signed out")
        } catch {
            showError("Failed to sign out: \(error.localizedDescription)")
        }
    }
    
    func deletePin(_ pin: Pin) async throws {
        // First check if user can edit this pin
        guard await userCanEditPin(pin) else {
            throw NSError(
                domain: "PinDeletion",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "You can only delete pins that you created on this device"]
            )
        }
        
        // Double check authentication
        guard let currentUserId = Auth.auth().currentUser?.uid,
              currentUserId == pin.userId else {
            throw NSError(
                domain: "PinDeletion",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Authentication error"]
            )
        }
        
        // If authorized, proceed with deletion
        if let videoURL = URL(string: pin.videoURL) {
            let storageRef = Storage.storage().reference(forURL: videoURL.absoluteString)
            try await storageRef.delete()
        }
        
        // Delete from Firestore
        try await FirebaseManager.shared.firestore().collection("pins").document(pin.id).delete()
        
        // Update local arrays on main thread
        await MainActor.run {
            self.pins.removeAll { $0.id == pin.id }
            self.filteredPins.removeAll { $0.id == pin.id }
            self.updateFilteredPins()
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
}

// MARK: - Location Manager Delegate
extension MapViewModel: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                // Only request location if we don't have one
                if locationManager.location == nil {
                    locationManager.requestLocation()
                }
            case .denied, .restricted:
                showError("Location access is required to use this app. Please enable it in Settings.")
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            @unknown default:
                showError("Unknown location authorization status")
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        Task { @MainActor in
            // Calculate span based on the pin drop limit
            let pinDropSpan = MKCoordinateSpan(
                latitudeDelta: MapConstants.pinDropLimit / 111000 * 2.5,
                longitudeDelta: MapConstants.pinDropLimit / 111000 * 2.5
            )
            
            let region = MKCoordinateRegion(
                center: location.coordinate,
                span: pinDropSpan
            )
            self.mapRegion = region
            print("Location updated: \(location.coordinate) with zoom level for 200ft pin drop radius")
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code != .locationUnknown {
            Task { @MainActor in
                self.showError("Location error: \(error.localizedDescription)")
            }
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
                uploadQueue.append((videoURL, coordinate, incidentType))
                
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
