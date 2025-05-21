import SwiftUI
import MapKit
import AVKit
import FirebaseAuth
// Import our utility extensions
import MetalKit

// Update the constants to be more specific and avoid naming conflicts
private enum MapViewConstants {
    static let pinDropLimit: CLLocationDistance = 200 * 0.3048 // 200 feet in meters
    static let defaultSpan = MKCoordinateSpan(
        latitudeDelta: pinDropLimit / 111000 * 2.5, // Convert meters to degrees with some padding
        longitudeDelta: pinDropLimit / 111000 * 2.5
    )
    static let minZoomDistance: CLLocationDistance = 50 // Reduced from 100 to allow closer zoom
    static let maxZoomDistance: CLLocationDistance = 80000 // Increased from 50000 to allow farther zoom out
    static let defaultAltitude: CLLocationDistance = 1000
    
    // Add minimum span to prevent over-zooming
    static let minSpan = MKCoordinateSpan(
        latitudeDelta: defaultSpan.latitudeDelta * 0.5, // Reduced from 0.8 to allow closer zoom
        longitudeDelta: defaultSpan.longitudeDelta * 0.5
    )
    
    // Safe validation helper for coordinate spans
    static func safeSpan(_ span: MKCoordinateSpan) -> MKCoordinateSpan {
        let deltaLat = span.latitudeDelta.isNaN || span.latitudeDelta <= 0 ? minSpan.latitudeDelta : span.latitudeDelta
        let deltaLon = span.longitudeDelta.isNaN || span.longitudeDelta <= 0 ? minSpan.longitudeDelta : span.longitudeDelta
        return MKCoordinateSpan(latitudeDelta: deltaLat, longitudeDelta: deltaLon)
    }
    
    // Safe validation helper for coordinates
    static func safeCoordinate(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let lat = coordinate.latitude.isNaN ? 0 : min(max(coordinate.latitude, -90), 90)
        let lon = coordinate.longitude.isNaN ? 0 : min(max(coordinate.longitude, -180), 180)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    // Safe validation for region
    static func safeRegion(_ region: MKCoordinateRegion) -> MKCoordinateRegion {
        let safeCenter = safeCoordinate(region.center)
        let safeSpan = safeSpan(region.span)
        return MKCoordinateRegion(center: safeCenter, span: safeSpan)
    }
}

class PinAnnotation: MKPointAnnotation {
    let pin: Pin
    
    init(pin: Pin) {
        self.pin = pin
        super.init()
        self.coordinate = pin.coordinate
        // Remove title since we're using glyphText
    }
}

struct MapView: UIViewRepresentable {
    @ObservedObject var viewModel: MapViewModel
    
    func makeUIView(context: Context) -> MKMapView {
        // Disable debug overlays using safer method
        disableDebugOverlays()
        
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        
        // Configure map appearance
        configureMapView(mapView)
        
        // Initialize the range visualization manager with this map view
        viewModel.setupRangeVisualization(on: mapView)
        
        // Explicitly enable interaction capabilities
        mapView.isScrollEnabled = true
        mapView.isZoomEnabled = true
        
        // Disable clustering
        mapView.register(
            MKMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier
        )
        
        // Set strict zoom level constraints
        mapView.cameraZoomRange = MKMapView.CameraZoomRange(
            minCenterCoordinateDistance: MapViewConstants.minZoomDistance,
            maxCenterCoordinateDistance: MapViewConstants.maxZoomDistance
        )
        
        // Set initial region with default coordinates
        let defaultCoordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let defaultRegion = MKCoordinateRegion(
            center: defaultCoordinate,
            span: MapViewConstants.defaultSpan
        )
        mapView.setRegion(defaultRegion, animated: false)
        
        // Try to update with user location after a delay
        Task { @MainActor in
            // Using a real async operation instead of try? await Task.sleep
            do {
                let _ = try await URLSession.shared.data(for: URLRequest(url: URL(string: "about:blank")!), delegate: nil)
            
                if let location = await viewModel.getCurrentLocation() {
                    let region = MKCoordinateRegion(
                        center: location.coordinate,
                        span: MapViewConstants.defaultSpan
                    )
                    mapView.setRegion(region, animated: false)
                }
            } catch {
                print("Error initializing map with user location: \(error.localizedDescription)")
            }
        }
        
        // Add gesture recognizer
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPress)
        
        return mapView
    }
    
    private func configureMapView(_ mapView: MKMapView) {
        // Configure base appearance with standard settings that don't require external style files
        mapView.mapType = .standard 
        mapView.showsUserLocation = true
        mapView.showsBuildings = true
        mapView.showsTraffic = false
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = true
        
        // Set clear tint color for better visibility
        mapView.tintColor = UIColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 1.0)
        
        // Set default camera position
        let camera = MKMapCamera()
        camera.pitch = 0
        camera.altitude = MapViewConstants.defaultAltitude
        mapView.camera = camera
        
        // Set default region (NYC as fallback if no location)
        let defaultCoordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let defaultRegion = MKCoordinateRegion(
            center: defaultCoordinate,
            span: MapViewConstants.defaultSpan
        )
        mapView.setRegion(defaultRegion, animated: false)
        
        print("DEBUG: MapView configured with mapType: \(mapView.mapType.rawValue)")
    }
    
    // Safe method to disable debug overlays via UserDefaults only
    private func disableDebugOverlays() {
        UserDefaults.standard.set(false, forKey: "MKShowsHybridFlyover")
        UserDefaults.standard.set(false, forKey: "MKShowsBuildings")
        UserDefaults.standard.set(false, forKey: "MKShowsTraffic")
        UserDefaults.standard.set(false, forKey: "MKShowsCompass")
        UserDefaults.standard.set(false, forKey: "MKZoomEnabled")
        UserDefaults.standard.set(false, forKey: "MKPitchEnabled")
        UserDefaults.standard.set(false, forKey: "MKScrollEnabled")
        UserDefaults.standard.set(false, forKey: "MKRotateEnabled")
    }
    
    // Helper method to load map style resources
    private func loadMapStyle(for mapType: MKMapType) -> URL? {
        switch mapType {
        case .satellite:
            // First try screen-specific versions
            let scale = UIScreen.main.scale
            if scale >= 3.0 {
                if let url = Bundle.mapStyleURL(name: "satellite@3x") {
                    return url
                }
            } else if scale >= 2.0 {
                if let url = Bundle.mapStyleURL(name: "satellite@2.6x") {
                    return url
                }
            }
            
            // Fall back to standard version
            return Bundle.mapStyleURL(name: "satellite")
            
        case .hybrid:
            return Bundle.mapStyleURL(name: "hybrid")
            
        case .standard, .mutedStandard:
            return Bundle.mapStyleURL(name: "default", ext: "json")
            
        default:
            return nil
        }
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // First, update pins if they've changed
        let _ = context.coordinator
        
        // Update map type if needed
        if mapView.mapType != viewModel.mapType {
            UIView.animate(withDuration: 0.3) {
                mapView.mapType = viewModel.mapType
                mapView.overrideUserInterfaceStyle = .dark
                
                // Try to load custom style if available
                if let styleURL = self.loadMapStyle(for: viewModel.mapType) {
                    print("Applied custom map style from: \(styleURL.path)")
                } else {
                    print("Using standard map type: \(viewModel.mapType.rawValue)")
                }
            }
        }
        
        // Ensure user location is always shown
        if !mapView.showsUserLocation {
            mapView.showsUserLocation = true
        }
        
        // Get existing pins from map
        let existingPins = mapView.annotations.compactMap { $0 as? PinAnnotation }
        let existingPinIds = Set(existingPins.map { $0.pin.id })
        
        // Get filtered pins from view model
        let filteredPins = viewModel.filteredPins
        
        // Find pins to add and remove
        let pinsToRemove = existingPins.filter { annotation in
            !filteredPins.contains { annotation.pin.id == $0.id }
        }
        let newPinAnnotations = filteredPins
            .filter { !existingPinIds.contains($0.id) }
            .map { PinAnnotation(pin: $0) }
        
        // Apply changes to map
        if !pinsToRemove.isEmpty {
            mapView.removeAnnotations(pinsToRemove)
        }
        
        if !newPinAnnotations.isEmpty {
            mapView.addAnnotations(newPinAnnotations)
        }
        
        // If region changed, update it (enforce minimum span for user experience)
        if let newRegion = viewModel.mapRegion {
            // Validate the region before applying it to prevent NaN values
            let safeRegion = MapViewConstants.safeRegion(newRegion)
            
            // Use enforcedSpan to ensure we don't zoom in too close
            let enforcedSpan = MKCoordinateSpan(
                latitudeDelta: max(safeRegion.span.latitudeDelta, MapViewConstants.minSpan.latitudeDelta),
                longitudeDelta: max(safeRegion.span.longitudeDelta, MapViewConstants.minSpan.longitudeDelta)
            )
            
            let regionToApply = MKCoordinateRegion(
                center: safeRegion.center,
                span: enforcedSpan
            )
            
            // Only update region if it's significantly different and coordinates are valid
            let currentCenter = MapViewConstants.safeCoordinate(mapView.region.center)
            let newCenter = safeRegion.center
            
            // Use validated point conversion to avoid NaN errors
            let distance = MKMapPoint(currentCenter).distance(to: MKMapPoint(newCenter))
            
            if distance > 100 || // If centers are more than 100 points apart
               abs(mapView.region.span.latitudeDelta - regionToApply.span.latitudeDelta) > 0.01 {
                mapView.setRegion(regionToApply, animated: true)
            }
            
            // Reset region after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak viewModel] in
                viewModel?.mapRegion = nil
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Add overlay to display upload progress
    static func dismantleUIView(_ uiView: MKMapView, coordinator: Coordinator) {
        // Clean up when view is removed
    }
}

// Add this extension to the MapView to include the upload progress overlay
extension MapView {
    func overlayView() -> some View {
        // This creates a transparent view that overlays the map
        // and shows the upload progress indicator when needed
        ZStack {
            Color.clear // Transparent background
            
            // Show upload progress indicator when uploading
            if viewModel.uploadProgress > 0 && viewModel.uploadProgress < 1.0 {
                UploadProgressOverlay(viewModel: viewModel)
            }

            // Banner for location denial
            if viewModel.isLimitedFunctionalityDueToLocationDenial {
                VStack {
                    Spacer() // Pushes content to the bottom
                    HStack {
                        Image(systemName: "location.slash.fill")
                            .foregroundColor(.white)
                        Text("Location disabled. Tap to enable for full features.")
                            .font(.footnote)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(10)
                    .padding(.horizontal) 
                    .padding(.bottom, 10) 
                    .onTapGesture {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            let env = UIApplication.shared
                            env.open(url, options: [:], completionHandler: nil)
                        }
                    }
                }
                .edgesIgnoringSafeArea(.bottom) // Allow background to extend towards edge
            }
        }
    }
}

class Coordinator: NSObject, MKMapViewDelegate {
    var parent: MapView
    var hasLoggedMapStatus = false
    
    init(_ parent: MapView) {
        self.parent = parent
    }
    
    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        // Respond to long-press only when NOT in delete-edit mode
        guard gesture.state == .began, parent.viewModel.isEditMode == false else { return }

        // Check if user is anonymous first
        if parent.viewModel.authState.isAnonymous {
            parent.viewModel.showError("Guests cannot drop new pins.")
            return
        }
        
        let point = gesture.location(in: gesture.view)
        let mapView = gesture.view as? MKMapView
        
        // Safely convert point to coordinate
        guard let mapView = mapView else { return }
        let coordinate = mapView.convert(point, toCoordinateFrom: gesture.view)
        
        // Validate coordinate to prevent NaN values
        guard coordinate.isValid else {
            parent.viewModel.showError("Invalid map location. Please try again.")
            return
        }
        
        // Check authentication first
        guard Auth.auth().currentUser != nil else {
            parent.viewModel.showError("You need to sign in to drop pins")
            return
        }
        
        // Check if location is within range (200 feet)
        Task { @MainActor in
            let isWithinRange = await parent.viewModel.isWithinPinDropRange(coordinate: coordinate)
            if isWithinRange {
                // Set the pending coordinate and show the incident picker directly
                parent.viewModel.pendingCoordinate = coordinate
                parent.viewModel.showingIncidentPicker = true
            } else {
                parent.viewModel.showError("You can only drop pins within 200 feet of your location")
            }
        }
    }
    
    // Implement MKMapViewDelegate methods to prevent unwanted zoom changes
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        let currentSpan = mapView.region.span
        
        // Prevent zooming in too far
        if currentSpan.latitudeDelta < MapViewConstants.minSpan.latitudeDelta ||
           currentSpan.longitudeDelta < MapViewConstants.minSpan.longitudeDelta {
            mapView.setRegion(MKCoordinateRegion(
                center: mapView.region.center,
                span: MapViewConstants.minSpan
            ), animated: false)
        }
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let circle = overlay as? MKCircle {
            let renderer = MKCircleRenderer(circle: circle)
            renderer.fillColor = UIColor.red.withAlphaComponent(0.15)
            renderer.strokeColor = UIColor.red.withAlphaComponent(0.8)
            renderer.lineWidth = 2.0
            return renderer
        } else if let tileOverlay = overlay as? MKTileOverlay {
            let renderer = MKTileOverlayRenderer(tileOverlay: tileOverlay)
            renderer.alpha = 0.8
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            let identifier = "UserLocation"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if view == nil {
                view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view?.image = UIImage(systemName: "location.fill")?.withTintColor(.red, renderingMode: .alwaysTemplate)
                view?.canShowCallout = false
            } else {
                view?.annotation = annotation
            }
            
            // Configure appearance
            view?.tintColor = UIColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 1.0)
            
            return view
        }
        
        if let pinAnnotation = annotation as? PinAnnotation {
            let identifier = "PinAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
                annotationView?.clusteringIdentifier = nil
            } else {
                annotationView?.annotation = annotation
            }
            
            // Configure pin appearance with neon styling
            annotationView?.glyphText = pinAnnotation.pin.incidentType.emoji
            
            // Set pin color based on incident type with neon effect
            let pinColor: UIColor
            switch pinAnnotation.pin.incidentType {
            case .verbal:
                pinColor = UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0) // Neon yellow
            case .physical:
                pinColor = UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0) // Neon red
            case .emergency:
                pinColor = UIColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0) // Neon green
            }
            
            annotationView?.markerTintColor = parent.viewModel.isEditMode ? .red : pinColor
            annotationView?.glyphTintColor = .white
            annotationView?.displayPriority = .required
            
            // Retain edit mode animation but remove shadow adjustments
            UIView.animate(withDuration: 0.3) {
                annotationView?.transform = self.parent.viewModel.isEditMode ?
                    CGAffineTransform(scaleX: 1.2, y: 1.2) : .identity
                if self.parent.viewModel.isEditMode {
                    // Shadow adjustments omitted in edit mode
                }
            }

            return annotationView
        }
        
        return nil
    }
    
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        views.forEach { view in
            view.alpha = 0
            
            UIView.animate(withDuration: 0.3) {
                view.alpha = 1
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation else { return }
        mapView.deselectAnnotation(annotation, animated: true)
        
        guard let pinAnnotation = annotation as? PinAnnotation else { return }
        let pin = pinAnnotation.pin

        if parent.viewModel.isEditMode {
            // Delete pin only if user owns it
            Task { @MainActor in
                if parent.viewModel.userCanEditPin(pin) {
                    do {
                        try await parent.viewModel.deletePin(pin)
                        // Add deletion animation
                        UIView.animate(withDuration: 0.3, animations: {
                            view.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
                            view.alpha = 0
                        }) { _ in
                            mapView.removeAnnotation(annotation)
                        }
                    } catch {
                        parent.viewModel.showError(error.localizedDescription)
                    }
                } else {
                    parent.viewModel.showError("You can only delete your own pins")
                }
            }
            return
        }
        
        // Play video logic refactored
        Task { @MainActor in
            // Set current video ID for flagging reference
            parent.viewModel.currentlyPlayingVideoId = pin.id
            var videoURLToPlay: URL? = nil
            var isLoadingIndicatorPresented = false
            var loadingAlert: UIAlertController? = nil

            do {
                // Ensure existing player is fully dismissed
                await dismissExistingPlayer(animated: true)
                
                // Show loading indicator
                loadingAlert = UIAlertController(title: "Loading Video", message: "Please wait...", preferredStyle: .alert)
                guard let rootVC = getRootViewController() else {
                    throw NSError(domain: "VideoPlayback", code: -5, userInfo: [NSLocalizedDescriptionKey: "Could not get root view controller."])
                }
                
                // Present loading alert
                rootVC.present(loadingAlert!, animated: true)
                isLoadingIndicatorPresented = true

                // Get video URL
                if pin.videoURL.isEmpty {
                    throw NSError(domain: "VideoPlayback", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video URL available."])
                }
                
                // Try to get from cache or URL
                if let cachedData = parent.viewModel.getCachedVideo(for: pin.videoURL), !cachedData.isEmpty {
                    print("Playing video from cache...")
                    videoURLToPlay = try createTemporaryFile(from: cachedData)
                } else if let remoteURL = URL(string: pin.videoURL) { 
                    // If URL is valid, play directly from it
                    print("Playing directly from URL...")
                    videoURLToPlay = remoteURL
                } else {
                    throw NSError(domain: "VideoPlayback", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid video URL."])
                }

                // Dismiss loading indicator
                if isLoadingIndicatorPresented {
                    await dismissViewController(loadingAlert, animated: true)
                    isLoadingIndicatorPresented = false
                    loadingAlert = nil
                }

                // Play the video
                if let url = videoURLToPlay {
                    await playVideo(from: url) 
                } else {
                    throw NSError(domain: "VideoPlayback", code: -3, userInfo: [NSLocalizedDescriptionKey: "Could not obtain a valid URL to play."])
                }

            } catch { 
                print("Error during video playback: \(error)")
                // Ensure loading indicator is dismissed
                if isLoadingIndicatorPresented, let alertToDismiss = loadingAlert {
                    await dismissViewController(alertToDismiss, animated: true)
                }
                parent.viewModel.showError("Failed to play video: \(error.localizedDescription)") 
            }
        }
    }
    
    // Helper to dismiss existing player, ensuring completion
    private func dismissExistingPlayer(animated: Bool) async {
         guard let rootViewController = getRootViewController(),
               rootViewController.presentedViewController is AVPlayerViewController else { return }
           
         await dismissViewController(rootViewController.presentedViewController, animated: animated)
    }
    
    // Generic helper to dismiss a view controller and wait for completion
    private func dismissViewController(_ viewController: UIViewController?, animated: Bool) async {
        guard let vc = viewController else { return }
        
        // Check if view controller is already being dismissed to avoid race conditions
        guard !vc.isBeingDismissed else {
            print("View controller is already being dismissed, skipping dismissal")
            return
        }
        
        // Use continuation to bridge completion handler
        await withCheckedContinuation { continuation in
            // Ensure we're on the main thread for UIKit operations
            DispatchQueue.main.async {
                if vc.isBeingPresented {
                    // If it's being presented, wait a bit and retry
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        vc.dismiss(animated: animated) {
                            continuation.resume()
                        }
                    }
                } else {
                    vc.dismiss(animated: animated) {
                        continuation.resume()
                    }
                }
            }
        }
        print("Dismiss completion handler executed for \(type(of: vc))") // Debug log
    }

    // Helper to get root view controller
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return nil }
        return window.rootViewController
    }

    // Helper to create temp file only when needed for AVPlayer
    private func createTemporaryFile(from data: Data) throws -> URL {
         let tempDir = FileManager.default.temporaryDirectory
         let tempFile = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
         try data.write(to: tempFile, options: .atomic)
         print("Created temporary video file for player: \(tempFile.path)")
         return tempFile
    }
    
    // playVideo function refined
    private func playVideo(from url: URL) async {
        // Create a local strong reference to any cleanup resources
        var notificationToken: Any?
        
        do {
            // 1. Create Asset from temp URL with explicit options for better memory management
            let options = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
            let asset = AVURLAsset(url: url, options: options)

            // 2. Load essential properties asynchronously with timeouts
            let loadDurationTask = Task {
                try await asset.load(.duration)
            }
            
            // Set a timeout of 5 seconds for loading duration
            let duration = try await withTimeout(task: loadDurationTask, seconds: 5)
            
            guard duration.seconds > 0 else {
                throw NSError(domain: "VideoPlayback", code: -10, 
                             userInfo: [NSLocalizedDescriptionKey: "Video asset has invalid duration."])
            }

            // Load tracks with timeout
            let loadTracksTask = Task {
                try await asset.loadTracks(withMediaType: .video)
            }
            
            let tracks = try await withTimeout(task: loadTracksTask, seconds: 5)
            
            guard !tracks.isEmpty else {
                throw NSError(domain: "VideoPlayback", code: -11,
                             userInfo: [NSLocalizedDescriptionKey: "Video asset has no video tracks."])
            }
            
            // 3. Create PlayerItem with explicit loading behavior
            let playerItem = AVPlayerItem(asset: asset)

            // 4. Setup Player and ViewController with memory management
            let player = AVPlayer(playerItem: playerItem)
            let playerViewController = AVPlayerViewController()
            playerViewController.player = player
            player.actionAtItemEnd = .pause
            
            // Add flag button to player UI
            let flagButton = UIButton(type: .system)
            flagButton.setImage(UIImage(systemName: "flag.fill"), for: .normal)
            flagButton.tintColor = UIColor.white
            flagButton.backgroundColor = UIColor(red: 0.8, green: 0.0, blue: 0.0, alpha: 0.7)
            flagButton.layer.cornerRadius = 15
            flagButton.tag = 100 // Tag to find button later
            
            // Configure button size and position
            flagButton.frame = CGRect(x: 20, y: 60, width: 30, height: 30)
            flagButton.addTarget(self, action: #selector(flagButtonTapped), for: .touchUpInside)
            
            // Add button to player view
            playerViewController.contentOverlayView?.addSubview(flagButton)
            
            guard let rootVC = getRootViewController() else {
                print("Error: Cannot present player, root VC not found.")
                try? FileManager.default.removeItem(at: url) // Clean up temp file
                return
            }
             
            // 5. Present player and wait for completion
            try await presentViewController(playerViewController, on: rootVC, animated: true)
            
            // Only play after presentation is complete
            DispatchQueue.main.async {
                player.play()
            }

            // 6. Setup temporary file cleanup observer with proper memory management
            notificationToken = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime, 
                object: playerItem,
                queue: .main
            ) { _ in 
                print("Player item finished playing. Cleaning up temp file: \(url.path)")
                try? FileManager.default.removeItem(at: url)
                
                // Also ensure we remove our notification observer to prevent memory leaks
                if let token = notificationToken {
                    NotificationCenter.default.removeObserver(token)
                    notificationToken = nil
                }
            }
            
        } catch let timeoutError as TimeoutError {
            parent.viewModel.showError("Video loading timed out: \(timeoutError.localizedDescription)")
            try? FileManager.default.removeItem(at: url) // Clean up temp file on error
            
        } catch {
            parent.viewModel.showError("Failed to play video: \(error.localizedDescription)")
            try? FileManager.default.removeItem(at: url) // Clean up temp file on error
        }
        
        // Ensure notification observer is removed if we exit the function without hitting play to end
        if let token = notificationToken {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1800) { // 30 min timeout
                NotificationCenter.default.removeObserver(token)
            }
        }
    }
    
    // Helper function for timeouts
    private func withTimeout<T>(task: Task<T, Error>, seconds: TimeInterval) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // Add the task to the group
            group.addTask {
                return try await task.value
            }
            
            // Add a timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError(message: "Operation timed out after \(seconds) seconds")
            }
            
            // Return the first completed task (or throw if both fail)
            do {
                let result = try await group.next()
                // Cancel the remaining task
                task.cancel()
                group.cancelAll()
                return result!
            } catch {
                // If we get here, the task threw an error
                task.cancel()
                group.cancelAll()
                throw error
            }
        }
    }
    
    // Error type for timeouts
    struct TimeoutError: Error, Sendable {
        let message: String
        
        var localizedDescription: String {
            return message
        }
    }
    
    @objc private func flagButtonTapped() {
        guard let rootVC = getRootViewController(),
              let playerVC = rootVC.presentedViewController as? AVPlayerViewController else {
            return
        }
        
        // Pause video
        playerVC.player?.pause()
        
        // Create custom alert using UIViewController
        let reportVC = UIViewController()
        reportVC.modalPresentationStyle = .formSheet
        reportVC.view.backgroundColor = UIColor(white: 0, alpha: 0.7)
        reportVC.preferredContentSize = CGSize(width: 300, height: 400)
        
        // Main container view
        let containerView = UIView()
        containerView.backgroundColor = UIColor(white: 0.2, alpha: 0.9)
        containerView.layer.cornerRadius = 15
        containerView.translatesAutoresizingMaskIntoConstraints = false
        reportVC.view.addSubview(containerView)
        
        // Title label
        let titleLabel = UILabel()
        titleLabel.text = "Report Video"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // Subtitle label
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Please provide your email and select a reason for reporting"
        subtitleLabel.textColor = .white
        subtitleLabel.font = UIFont.systemFont(ofSize: 16)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(subtitleLabel)
        
        // Email text field
        let emailField = UITextField()
        emailField.placeholder = "Your email address"
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        emailField.backgroundColor = .white
        emailField.layer.cornerRadius = 8
        emailField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: emailField.frame.height))
        emailField.leftViewMode = .always
        emailField.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(emailField)
        
        // Fix input assistant view issue
        emailField.inputAssistantItem.leadingBarButtonGroups = []
        emailField.inputAssistantItem.trailingBarButtonGroups = []
        
        // Add keyboard dismissal functionality
        emailField.returnKeyType = .done
        emailField.delegate = self
        
        // Add a done button to the keyboard
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        toolbar.barStyle = .default
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissKeyboard))
        toolbar.items = [flexSpace, doneButton]
        toolbar.sizeToFit()
        emailField.inputAccessoryView = toolbar
        
        // Reason selection segment control (simpler than picker)
        let reasons = ["Inappropriate", "Misleading", "Harmful"]
        let reasonSegment = UISegmentedControl(items: reasons)
        reasonSegment.selectedSegmentIndex = 0 // Default selection
        reasonSegment.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        reasonSegment.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(reasonSegment)
        
        // Buttons container
        let buttonsContainer = UIStackView()
        buttonsContainer.axis = .horizontal
        buttonsContainer.distribution = .fillEqually
        buttonsContainer.spacing = 10
        buttonsContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(buttonsContainer)
        
        // Cancel button
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.systemBlue, for: .normal)
        cancelButton.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        cancelButton.layer.cornerRadius = 8
        
        // Submit button
        let submitButton = UIButton(type: .system)
        submitButton.setTitle("Submit", for: .normal)
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.backgroundColor = .systemBlue
        submitButton.layer.cornerRadius = 8
        
        buttonsContainer.addArrangedSubview(cancelButton)
        buttonsContainer.addArrangedSubview(submitButton)
        
        // Layout constraints for container
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: reportVC.view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: reportVC.view.centerYAnchor),
            containerView.widthAnchor.constraint(equalTo: reportVC.view.widthAnchor, multiplier: 0.9),
            containerView.heightAnchor.constraint(lessThanOrEqualTo: reportVC.view.heightAnchor, multiplier: 0.7)
        ])
        
        // Layout constraints for elements inside container
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 15),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            emailField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            emailField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            emailField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            emailField.heightAnchor.constraint(equalToConstant: 44),
            
            reasonSegment.topAnchor.constraint(equalTo: emailField.bottomAnchor, constant: 20),
            reasonSegment.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            reasonSegment.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            reasonSegment.heightAnchor.constraint(equalToConstant: 44),
            
            buttonsContainer.topAnchor.constraint(equalTo: reasonSegment.bottomAnchor, constant: 25),
            buttonsContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            buttonsContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            buttonsContainer.heightAnchor.constraint(equalToConstant: 44),
            buttonsContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
        
        // Set up button actions
        let cancelAction = UIAction { _ in
            reportVC.dismiss(animated: true) {
                // Resume video playback
                playerVC.player?.play()
            }
        }
        cancelButton.addAction(cancelAction, for: .touchUpInside)
        
        // Submit button action with weak self reference
        let submitAction = UIAction { [weak self] _ in
            guard let self = self,
                  let email = emailField.text, 
                  !email.isEmpty else {
                // Show error for missing email
                let alert = UIAlertController(
                    title: "Email Required",
                    message: "Please enter your email address.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                reportVC.present(alert, animated: true)
                return
            }
            
            // Get selected reason
            let reasonIndex = reasonSegment.selectedSegmentIndex
            let reason = reasons[reasonIndex]
            
            // Send flag report
            self.submitFlagReport(email: email, reason: reason)
            
            // Dismiss everything
            reportVC.dismiss(animated: true) {
                Task {
                    await self.dismissViewController(playerVC, animated: true)
                    
                    // Show confirmation alert
                    let confirmAlert = UIAlertController(
                        title: "Report Submitted",
                        message: "Thank you. We'll review this video and contact you at \(email).",
                        preferredStyle: .alert
                    )
                    confirmAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    rootVC.present(confirmAlert, animated: true)
                }
            }
        }
        submitButton.addAction(submitAction, for: .touchUpInside)
        
        // Add tap gesture to dismiss keyboard when tapping outside
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        reportVC.view.addGestureRecognizer(tapGesture)
        
        // Present the custom alert
        playerVC.present(reportVC, animated: true)
    }
    
    private func submitFlagReport(email: String, reason: String) {
        // Implement Firebase submission
        Task {
            do {
                // Use the MapViewModel's reportVideo method instead of accessing db directly
                let videoId = parent.viewModel.currentlyPlayingVideoId ?? "unknown"
                try await parent.viewModel.reportVideo(email: email, reason: reason, videoId: videoId)
                print("Flag report submitted successfully")
            } catch {
                print("Error submitting flag report: \(error.localizedDescription)")
            }
        }
    }
    
    // Generic helper to present a view controller and wait for completion
    private func presentViewController(_ viewControllerToPresent: UIViewController, on presentingViewController: UIViewController, animated: Bool) async throws {
        // Safety check - don't try to present a view controller that's already being presented
        guard !viewControllerToPresent.isBeingPresented else {
            print("View controller is already being presented, skipping presentation")
            return
        }
        
        // Safety check - ensure presenter is not already presenting something else
        if presentingViewController.presentedViewController != nil && 
           presentingViewController.presentedViewController !== viewControllerToPresent {
            // Attempt to dismiss the current presented view controller first
            await dismissViewController(presentingViewController.presentedViewController, animated: false)
        }
        
        // Use continuation to bridge completion handler and handle potential errors
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // Ensure we're on the main thread for UIKit operations
            DispatchQueue.main.async {
                presentingViewController.present(viewControllerToPresent, animated: animated) {
                    // Resume continuation when presentation is complete
                    continuation.resume()
                }
            }
        }
        print("Presentation completion handler executed for \(type(of: viewControllerToPresent))") // Debug log
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        // Silently update the map region without debug logs
        if let currentRegion = self.parent.viewModel.mapRegion,
           (currentRegion.center.latitude != mapView.region.center.latitude ||
            currentRegion.center.longitude != mapView.region.center.longitude ||
            currentRegion.span.latitudeDelta != mapView.region.span.latitudeDelta ||
            currentRegion.span.longitudeDelta != mapView.region.span.longitudeDelta) {
            DispatchQueue.main.async {
                self.parent.viewModel.mapRegion = mapView.region
            }
        }
    }
}

// Helper extension for array safe subscript
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - UITextFieldDelegate Implementation
extension Coordinator: UITextFieldDelegate {
    @objc func dismissKeyboard() {
        // Find and resign first responder to dismiss keyboard
        if let rootVC = getRootViewController(),
           let presentedVC = rootVC.presentedViewController,
           let contentView = presentedVC.presentedViewController?.view {
            contentView.endEditing(true)
        } else if let rootVC = getRootViewController(),
                  let presentedVC = rootVC.presentedViewController {
            presentedVC.view.endEditing(true)
        }
    }
    
    // Implement UITextFieldDelegate methods
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // Optional: Add validation for email format
    func textFieldDidEndEditing(_ textField: UITextField) {
        // You could add email validation here if desired
        if let email = textField.text, !email.isEmpty {
            if !email.contains("@") || !email.contains(".") {
                // Show warning about invalid email format
                if let rootVC = getRootViewController(),
                   let presentedVC = rootVC.presentedViewController {
                    let alert = UIAlertController(
                        title: "Invalid Email",
                        message: "Please enter a valid email address.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    presentedVC.present(alert, animated: true)
                }
            }
        }
    }
} 

