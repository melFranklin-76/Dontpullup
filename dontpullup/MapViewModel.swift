import SwiftUI
import MapKit
import CoreLocation
import PhotosUI
import AVKit
import UniformTypeIdentifiers
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

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
    
    // MARK: - Initialization
    override init() {
        // Initialize location manager before super.init()
        locationManager = CLLocationManager()
        
        // Configure cache with size limits
        cache.countLimit = 50 // Maximum number of items
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit
        
        super.init()
        
        // Configure location manager
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = false
        
        // Setup offline support
        setupOfflineSupport()
        
        // Load cached data if available
        loadCachedData()
    }
    
    deinit {
        uploadTasks.forEach { $0.cancel() }
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleAppBackground() {
        // Request background time for uploads
        if !uploadQueue.isEmpty || isUploadInProgress {
            var taskID: UIBackgroundTaskIdentifier = .invalid
            
            taskID = UIApplication.shared.beginBackgroundTask { [taskID] in
                // End the task if the background task expires
                UIApplication.shared.endBackgroundTask(taskID)
            }
            
            if taskID != .invalid {
                // Continue processing upload queue
                processUploadQueue()
                
                // End the task when done
                UIApplication.shared.endBackgroundTask(taskID)
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
        guard !isUploadInProgress, !uploadQueue.isEmpty else { return }
        
        let (videoURL, coordinate, incidentType) = uploadQueue.removeFirst()
        
        Task {
            do {
                isUploadInProgress = true
                pendingCoordinate = coordinate
                currentIncidentType = incidentType
                
                try await processAndUploadVideo(from: videoURL)
                
                // Success - reset retry count and process next in queue
                currentRetryCount = 0
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
                self.processUploadQueue()
            }
        } else {
            // Max retries reached
            showError("Upload failed after multiple attempts: \(error.localizedDescription)")
            currentRetryCount = 0
            isUploadInProgress = false
            
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
        
        // Request location permissions
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        
        // Get initial location only
        if locationManager.authorizationStatus == .authorizedWhenInUse ||
           locationManager.authorizationStatus == .authorizedAlways {
            locationManager.requestLocation() // Only get location once
        }
    }
    
    // MARK: - Public Methods
    func toggleMapType() {
        switch mapType {
        case .standard: mapType = .satellite
        case .satellite: mapType = .hybrid
        case .hybrid: mapType = .mutedStandard
        default: mapType = .standard
        }
    }
    
    func centerOnUserLocation() {
        // Request a fresh location update when user explicitly asks to center
        if locationManager.authorizationStatus == .authorizedWhenInUse ||
           locationManager.authorizationStatus == .authorizedAlways {
            locationManager.requestLocation()
        } else {
            showError("Unable to determine your location. Please ensure location services are enabled.")
        }
    }
    
    func toggleEditMode() {
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
        filteredPins = selectedFilters.isEmpty ? pins : pins.filter { selectedFilters.contains($0.incidentType) }
    }
    
    nonisolated func showError(_ message: String) {
        Task { @MainActor in
            self.alertMessage = message
            self.showAlert = true
        }
    }
    
    // MARK: - Video Processing Methods
    private func processAndUploadVideo(from videoURL: URL) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "VideoUpload", code: -1, userInfo: [NSLocalizedDescriptionKey: "You must be logged in to upload videos"])
        }
        
        guard let coordinate = pendingCoordinate,
              let incidentType = currentIncidentType else {
            throw NSError(domain: "VideoUpload", code: -2, userInfo: [NSLocalizedDescriptionKey: "Missing location or incident type"])
        }
        
        // Get device identifier
        guard let deviceId = UIDevice.current.identifierForVendor?.uuidString else {
            throw NSError(domain: "VideoUpload", code: -3, userInfo: [NSLocalizedDescriptionKey: "Could not identify device"])
        }
        
        // Check video duration
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let durationInSeconds = CMTimeGetSeconds(duration)
        let maxDuration: Double = 300 // 5 minutes in seconds
        
        guard durationInSeconds <= maxDuration else {
            throw NSError(
                domain: "VideoUpload",
                code: -5,
                userInfo: [NSLocalizedDescriptionKey: "Video is too long. Please limit videos to 5 minutes or less. For longer videos, please contact support@dontpullup.temp"]
            )
        }
        
        // Check file size before compression
        let attributes = try FileManager.default.attributesOfItem(atPath: videoURL.path)
        let fileSizeBytes = attributes[.size] as? Int64 ?? 0
        let maxSizeBytes: Int64 = 100 * 1024 * 1024 // 100MB
        
        if fileSizeBytes > maxSizeBytes {
            throw NSError(domain: "VideoUpload", code: -4, userInfo: [NSLocalizedDescriptionKey: "Video file is too large. Please select a shorter video."])
        }
        
        let compressedURL = try await compressVideo(at: videoURL)
        
        // Generate a unique filename with timestamp and device ID
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "video_\(UUID().uuidString)_\(timestamp)_\(currentUserId)_\(deviceId).mp4"
        let storageRef = Storage.storage().reference().child("videos/\(filename)")
        
        do {
            let downloadURL = try await uploadVideo(compressedURL, to: storageRef)
            
            let pin = Pin(
                id: UUID().uuidString,
                coordinate: coordinate,
                incidentType: incidentType,
                videoURL: downloadURL,
                userId: currentUserId
            )
            
            // Store additional metadata in Firestore
            try await Firestore.firestore().collection("pins").document(pin.id).setData([
                "latitude": pin.coordinate.latitude,
                "longitude": pin.coordinate.longitude,
                "type": pin.incidentType.firestoreType,
                "videoURL": pin.videoURL,
                "timestamp": FieldValue.serverTimestamp(),
                "userID": pin.userId,
                "deviceID": deviceId  // Store device ID in Firestore
            ])
            
            await MainActor.run {
                pins.append(pin)
                updateFilteredPins()
                isUploading = false
                uploadProgress = 0
                pendingCoordinate = nil
                currentIncidentType = nil
            }
            
            // Cleanup files
            try? FileManager.default.removeItem(at: compressedURL)
            if compressedURL != videoURL {
                try? FileManager.default.removeItem(at: videoURL)
            }
        } catch {
            // Cleanup on error
            try? FileManager.default.removeItem(at: compressedURL)
            if compressedURL != videoURL {
                try? FileManager.default.removeItem(at: videoURL)
            }
            throw error
        }
    }
    
    @MainActor
    private func compressVideo(at url: URL) async throws -> URL {
        let asset = AVAsset(url: url)
        
        // Create a temporary file URL for the compressed video
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        // Configure export session
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetMediumQuality
        ) else {
            throw NSError(domain: "VideoCompression", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not create export session"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                exportSession.outputURL = outputURL
                exportSession.outputFileType = .mp4
                exportSession.shouldOptimizeForNetworkUse = true
                
                await exportSession.export()
                
                await MainActor.run {
                    switch exportSession.status {
                    case .completed:
                        continuation.resume(returning: outputURL)
                    case .failed:
                        continuation.resume(throwing: exportSession.error ?? NSError(domain: "VideoCompression", code: -1))
                    case .cancelled:
                        continuation.resume(throwing: NSError(domain: "VideoCompression", code: -2))
                    default:
                        continuation.resume(throwing: NSError(domain: "VideoCompression", code: -3))
                    }
                }
            }
        }
    }
    
    private func uploadVideo(_ videoURL: URL, to storageRef: StorageReference) async throws -> String {
        // Check if upload is already in progress
        guard !isUploadInProgress else {
            throw NSError(
                domain: "VideoUpload",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "An upload is already in progress"]
            )
        }
        
        isUploadInProgress = true
        defer { isUploadInProgress = false }
        
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        
        return try await withCheckedThrowingContinuation { continuation in
            let uploadTask = storageRef.putFile(from: videoURL, metadata: metadata)
            uploadTasks.append(uploadTask)
            
            uploadTask.observe(.progress) { [weak self] snapshot in
                guard let progress = snapshot.progress else { return }
                Task { @MainActor in
                    self?.uploadProgress = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                }
            }
            
            uploadTask.observe(.success) { [weak self] _ in
                Task {
                    do {
                        let downloadURL = try await storageRef.downloadURL()
                        continuation.resume(returning: downloadURL.absoluteString)
                        
                        await MainActor.run {
                            self?.uploadTasks.removeAll { $0 === uploadTask }
                        }
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            uploadTask.observe(.failure) { [weak self] snapshot in
                Task { @MainActor in
                    self?.uploadTasks.removeAll { $0 === uploadTask }
                    continuation.resume(throwing: snapshot.error ?? NSError(domain: "VideoUpload", code: -1))
                }
            }
        }
    }
    
    private func observePins() {
        let db = Firestore.firestore()
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings()
        db.settings = settings
        
        // Setup offline persistence
        offlineListener = db.collection("pins")
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    if (error as NSError).domain == "FIRFirestoreErrorDomain" && 
                       (error as NSError).code == 8 { // Unavailable error
                        // Network error - use cached data
                        return
                    }
                    self.showError("Failed to fetch pins: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                // Check if data is from cache
                let isFromCache = snapshot.metadata.isFromCache
                
                Task {
                    do {
                        let newPins = try await withThrowingTaskGroup(of: Pin?.self) { group in
                            for document in snapshot.documents {
                                group.addTask {
                                    let data = document.data()
                                    
                                    guard let latitude = data["latitude"] as? Double,
                                          let longitude = data["longitude"] as? Double,
                                          let typeString = data["type"] as? String,
                                          let videoURL = data["videoURL"] as? String,
                                          let userId = data["userID"] as? String else {
                                        return nil
                                    }
                                    
                                    let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                                    
                                    let incidentType: IncidentType
                                    switch typeString {
                                    case "Verbal": incidentType = .verbal
                                    case "Physical": incidentType = .physical
                                    case "911": incidentType = .emergency
                                    default: return nil
                                    }
                                    
                                    // If online, cache video for offline use
                                    if !isFromCache {
                                        if let url = URL(string: videoURL) {
                                            try? await self.cacheVideo(from: url, key: videoURL)
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
                            }
                            
                            var pins: [Pin] = []
                            for try await pin in group {
                                if let pin = pin {
                                    pins.append(pin)
                                }
                            }
                            return pins
                        }
                        
                        await MainActor.run {
                            self.pins = newPins
                            self.updateFilteredPins()
                            // Cache pins for offline use
                            self.cachePins(newPins)
                        }
                    } catch {
                        await MainActor.run {
                            self.showError("Failed to process pins: \(error.localizedDescription)")
                        }
                    }
                }
            }
    }
    
    func deletePin(_ pin: Pin) async throws {
        // First check if user can edit this pin
        guard await userCanEditPin(pin) else {
            throw NSError(
                domain: "PinDeletion",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "You can only delete your own pins"]
            )
        }
        
        // If authorized, proceed with deletion
        if let videoURL = URL(string: pin.videoURL) {
            let storageRef = Storage.storage().reference(forURL: videoURL.absoluteString)
            try await storageRef.delete()
        }
        
        // Delete from Firestore
        try await Firestore.firestore().collection("pins").document(pin.id).delete()
        
        // Update local arrays on main thread
        await MainActor.run {
            self.pins.removeAll { $0.id == pin.id }
            self.filteredPins.removeAll { $0.id == pin.id }
            self.updateFilteredPins()
        }
    }
    
    func userCanEditPin(_ pin: Pin) async -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return false
        }
        
        // Check if the pin belongs to the current user
        guard pin.userId == currentUserId else {
            return false
        }
        
        // Additional device check
        guard let deviceId = UIDevice.current.identifierForVendor?.uuidString else {
            return false
        }
        
        // Get the device ID from the pin's videoURL
        // Format: video_UUID_timestamp_userId_deviceId.mp4
        let components = pin.videoURL.components(separatedBy: "_")
        guard components.count >= 4 else {
            return false
        }
        
        // Extract deviceId from the filename (remove .mp4 extension)
        let pinDeviceId = components.last?.replacingOccurrences(of: ".mp4", with: "") ?? ""
        
        // Must match both user ID and device ID
        return pinDeviceId == deviceId
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
    
    private func loadVideo(from result: PHPickerResult) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let originalURL = url else {
                    continuation.resume(throwing: NSError(domain: "VideoLoad", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid video file"]))
                    return
                }
                
                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let tempFileName = "\(UUID().uuidString)_temp.mov"
                let tempURL = documentsDirectory.appendingPathComponent(tempFileName)
                
                do {
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
    
    private func loadCachedPins() {
        if let cachedPinsData = UserDefaults.standard.data(forKey: "CachedPins"),
           let cachedPins = try? JSONDecoder().decode([CachedPin].self, from: cachedPinsData) {
            self.pins = cachedPins.map { $0.toPin() }
            self.updateFilteredPins()
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
        let cacheDir = getCacheDirectory()
        if !fileManager.fileExists(atPath: cacheDir.path) {
            try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        cleanupOldCache()
    }
    
    private func cleanupOldCache() {
        Task.detached {
            let cacheDir = await self.getCacheDirectory()
            let resourceKeys: [URLResourceKey] = [.creationDateKey, .totalFileAllocatedSizeKey]
            
            guard let fileURLs = try? FileManager.default.contentsOfDirectory(at: cacheDir,
                                                                            includingPropertiesForKeys: resourceKeys,
                                                                            options: .skipsHiddenFiles) else {
                return
            }
            
            let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            
            for fileURL in fileURLs {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                      let creationDate = resourceValues.creationDate else {
                    continue
                }
                
                // Remove files older than a week or if we're over the cache limit
                if creationDate < oneWeekAgo {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
        }
    }
    
    private func getCacheDirectory() -> URL {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("VideoCache")
    }
    
    private func getVideoCacheURL(for videoURL: String) -> URL {
        let cacheDir = getCacheDirectory()
        let fileName = videoURL.replacingOccurrences(of: "/", with: "_")
        return cacheDir.appendingPathComponent(fileName)
    }
    
    func cacheVideo(from url: URL, key: String) async throws {
        // Use URLSession for async loading
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // Check cache size before adding new video
        await manageCacheSize(newDataSize: data.count)
        
        // Cache in memory
        cache.setObject(data as NSData, forKey: key as NSString)
        
        // Cache to disk
        let cacheURL = getVideoCacheURL(for: key)
        try data.write(to: cacheURL)
    }
    
    private func loadVideoData(from url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
    
    private func manageCacheSize(newDataSize: Int) async {
        let maxCacheSize: Int = 500 * 1024 * 1024 // 500MB
        let cacheDir = getCacheDirectory()
        
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(at: cacheDir,
                                                                        includingPropertiesForKeys: [.fileSizeKey],
                                                                        options: .skipsHiddenFiles) else {
            return
        }
        
        // Calculate current cache size
        var currentSize = 0
        var fileSizes: [(url: URL, size: Int, date: Date)] = []
        
        for fileURL in fileURLs {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey]),
                  let fileSize = resourceValues.fileSize,
                  let creationDate = resourceValues.creationDate else {
                continue
            }
            
            currentSize += fileSize
            fileSizes.append((fileURL, fileSize, creationDate))
        }
        
        // If adding new data would exceed cache limit, remove oldest files
        if currentSize + newDataSize > maxCacheSize {
            // Sort by date, oldest first
            let sortedFiles = fileSizes.sorted { $0.date < $1.date }
            
            var sizeToFree = (currentSize + newDataSize) - maxCacheSize + (10 * 1024 * 1024) // Extra 10MB buffer
            
            for file in sortedFiles {
                if sizeToFree <= 0 { break }
                
                do {
                    try FileManager.default.removeItem(at: file.url)
                    sizeToFree -= file.size
                    
                    // Also remove from memory cache
                    let key = file.url.lastPathComponent as NSString
                    cache.removeObject(forKey: key)
                } catch {
                    print("Error removing cached file: \(error)")
                }
            }
        }
    }
    
    func getCachedVideo(for key: String) -> Data? {
        // Check memory cache first
        if let cachedData = cache.object(forKey: key as NSString) {
            return cachedData as Data
        }
        
        // Check disk cache
        let cacheURL = getVideoCacheURL(for: key)
        if let data = try? Data(contentsOf: cacheURL) {
            // Add back to memory cache
            cache.setObject(data as NSData, forKey: key as NSString)
            return data
        }
        
        return nil
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
        offlineListener = Firestore.firestore().collection("pins")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Firestore offline error: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                Task { @MainActor in
                    // Convert documents to Pin models
                    let pins = snapshot.documents.compactMap { document -> Pin? in
                        let data = document.data()
                        guard let latitude = data["latitude"] as? Double,
                              let longitude = data["longitude"] as? Double,
                              let typeString = data["type"] as? String,
                              let videoURL = data["videoURL"] as? String,
                              let userId = data["userID"] as? String else {
                            return nil
                        }
                        
                        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                        let incidentType: IncidentType
                        switch typeString {
                        case "Verbal": incidentType = .verbal
                        case "Physical": incidentType = .physical
                        case "911": incidentType = .emergency
                        default: return nil
                        }
                        
                        return Pin(
                            id: document.documentID,
                            coordinate: coordinate,
                            incidentType: incidentType,
                            videoURL: videoURL,
                            userId: userId
                        )
                    }
                    
                    // Cache the pins
                    if let encodedPins = try? JSONEncoder().encode(pins) {
                        self.cache.setObject(encodedPins as NSData, forKey: "pins" as NSString)
                    }
                    
                    // Update pins
                    self.pins = pins
                    self.updateFilteredPins()
                }
            }
    }
    
    private func loadCachedData() {
        if let cachedData = cache.object(forKey: "pins" as NSString) as? Data,
           let pins = try? JSONDecoder().decode([Pin].self, from: cachedData) {
            self.pins = pins
            updateFilteredPins()
        }
    }
}

// MARK: - Location Manager Delegate
extension MapViewModel: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                locationManager.requestLocation() // Only get location once
            case .denied, .restricted:
                showError("Location access is required to use this app. Please enable it in Settings.")
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            @unknown default:
                break
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        Task { @MainActor in
            let region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            self.mapRegion = region
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Only show error for significant location errors
        if (error as? CLError)?.code != .locationUnknown {
            Task { @MainActor in
                self.showError("Location error: \(error.localizedDescription). Please ensure location services are enabled.")
                // Don't retry automatically - user must initiate location updates
            }
        }
    }
}

// MARK: - PHPicker Delegate
extension MapViewModel: PHPickerViewControllerDelegate {
    nonisolated func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        Task { @MainActor in
            defer {
                if let presentingVC = picker.presentingViewController {
                    presentingVC.dismiss(animated: true)
                }
            }
            
            guard let result = results.first else {
                pendingCoordinate = nil
                currentIncidentType = nil
                isUploading = false
                return
            }
            
            guard result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
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
            
            isUploading = true
            uploadProgress = 0.01
            
            do {
                let videoURL = try await loadVideo(from: result)
                uploadQueue.append((videoURL, coordinate, incidentType))
                processUploadQueue()
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
