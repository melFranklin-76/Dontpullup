import SwiftUI
import MapKit
import AVKit

// Update the constants to be more specific and avoid naming conflicts
private enum MapViewConstants {
    static let pinDropLimit: CLLocationDistance = 200 * 0.3048 // 200 feet in meters
    static let defaultSpan = MKCoordinateSpan(
        latitudeDelta: pinDropLimit / 111000 * 2.5, // Convert meters to degrees with some padding
        longitudeDelta: pinDropLimit / 111000 * 2.5
    )
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
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        
        // Configure map appearance
        configureMapView(mapView)
        
        // Disable clustering
        mapView.register(
            MKMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier
        )
        
        // Set zoom level constraints
        let minDistance: CLLocationDistance = 100
        let maxDistance: CLLocationDistance = 50000
        mapView.cameraZoomRange = MKMapView.CameraZoomRange(
            minCenterCoordinateDistance: minDistance,
            maxCenterCoordinateDistance: maxDistance
        )
        
        // Optimize performance
        if mapView.responds(to: NSSelectorFromString("setPreferredFramesPerSecond:")) {
            mapView.setValue(30, forKey: "preferredFramesPerSecond")
        }
        
        // Add gesture recognizer
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPress)
        
        return mapView
    }
    
    private func configureMapView(_ mapView: MKMapView) {
        // Configure base appearance
        mapView.mapType = .mutedStandard
        mapView.overrideUserInterfaceStyle = .dark
        mapView.showsBuildings = false
        mapView.showsTraffic = false
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        
        // Set vibrant tint color
        mapView.tintColor = UIColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 1.0)
        
        // Configure user location view appearance
        if let userLocationView = mapView.view(for: mapView.userLocation) {
            userLocationView.tintColor = UIColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 1.0)
            userLocationView.canShowCallout = false
        }
        
        // Set default camera position
        let camera = MKMapCamera()
        camera.pitch = 0
        camera.altitude = 1000
        mapView.camera = camera
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update map type with animation if needed
        if mapView.mapType != viewModel.mapType {
            // Ensure we're on the main thread
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.3) {
                    mapView.mapType = viewModel.mapType
                    
                    // Ensure dark mode and style consistency
                    mapView.overrideUserInterfaceStyle = .dark
                    
                    // Reset camera pitch to prevent style loading issues
                    let camera = mapView.camera
                    camera.pitch = 0
                    mapView.camera = camera
                }
            }
        }
        
        // Batch annotation updates
        let currentAnnotations = mapView.annotations.compactMap { $0 as? PinAnnotation }
        let newPins = viewModel.filteredPins
        
        // Calculate differences
        let annotationsToRemove = currentAnnotations.filter { annotation in
            !newPins.contains { $0.id == annotation.pin.id }
        }
        
        let existingPinIds = Set(currentAnnotations.map { $0.pin.id })
        let newAnnotations = newPins
            .filter { !existingPinIds.contains($0.id) }
            .map { PinAnnotation(pin: $0) }
        
        // Apply updates in a batch
        if !annotationsToRemove.isEmpty || !newAnnotations.isEmpty {
            mapView.removeAnnotations(annotationsToRemove)
            mapView.addAnnotations(newAnnotations)
        }
        
        // Update region if needed with smooth animation
        if let newRegion = viewModel.mapRegion {
            let region = MKCoordinateRegion(
                center: newRegion.center,
                span: MKCoordinateSpan(
                    latitudeDelta: max(newRegion.span.latitudeDelta, MapViewConstants.defaultSpan.latitudeDelta),
                    longitudeDelta: max(newRegion.span.longitudeDelta, MapViewConstants.defaultSpan.longitudeDelta)
                )
            )
            
            mapView.setRegion(region, animated: true)
            
            // Reset region after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak viewModel] in
                viewModel?.mapRegion = nil
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        
        init(_ parent: MapView) {
            self.parent = parent
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began else { return }
            
            let point = gesture.location(in: gesture.view)
            let coordinate = (gesture.view as? MKMapView)?.convert(point, toCoordinateFrom: gesture.view)
            
            guard let validCoordinate = coordinate else { return }
            
            // Update coordinates on next runloop to avoid view update conflicts
            DispatchQueue.main.async {
                self.parent.viewModel.pendingCoordinate = validCoordinate
                self.parent.viewModel.showingIncidentPicker = true
            }
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tileOverlay)
                renderer.alpha = 0.8 // Adjust for desired neon effect intensity
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
                
                // Add glow effect
                view?.layer.shadowColor = UIColor.red.cgColor
                view?.layer.shadowRadius = 8
                view?.layer.shadowOpacity = 0.8
                view?.layer.shadowOffset = .zero
                
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
                
                // Enhanced glow effect
                annotationView?.layer.shadowColor = pinColor.cgColor
                annotationView?.layer.shadowOffset = CGSize(width: 0, height: 2)
                annotationView?.layer.shadowOpacity = 0.8
                annotationView?.layer.shadowRadius = 8
                
                // Add animation for edit mode changes with glow
                UIView.animate(withDuration: 0.3) {
                    annotationView?.transform = self.parent.viewModel.isEditMode ? 
                        CGAffineTransform(scaleX: 1.2, y: 1.2) : .identity
                    
                    if self.parent.viewModel.isEditMode {
                        annotationView?.layer.shadowColor = UIColor.red.cgColor
                        annotationView?.layer.shadowOpacity = 1.0
                        annotationView?.layer.shadowRadius = 12
                    }
                }
                
                return annotationView
            }
            
            return nil
        }
        
        func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
            views.forEach { view in
                view.alpha = 0
                
                // Add neon pulse animation
                let pulseAnimation = CABasicAnimation(keyPath: "shadowOpacity")
                pulseAnimation.duration = 1.5
                pulseAnimation.fromValue = 0.4
                pulseAnimation.toValue = 0.8
                pulseAnimation.autoreverses = true
                pulseAnimation.repeatCount = .infinity
                view.layer.add(pulseAnimation, forKey: "pulse")
                
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
                    if await parent.viewModel.userCanEditPin(pin) {
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
            
            // Play video immediately
            if let videoURL = URL(string: pin.videoURL) {
                Task { @MainActor in
                    do {
                        // Check if there's already a video being presented
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootViewController = windowScene.windows.first?.rootViewController,
                           rootViewController.presentedViewController != nil {
                            // Dismiss any existing presentation first
                            await withCheckedContinuation { continuation in
                                rootViewController.dismiss(animated: true) {
                                    continuation.resume()
                                }
                            }
                        }
                        
                        // Show loading indicator
                        let loadingAlert = UIAlertController(
                            title: "Loading Video",
                            message: "Please wait...",
                            preferredStyle: .alert
                        )
                        
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootViewController = windowScene.windows.first?.rootViewController {
                            rootViewController.present(loadingAlert, animated: true)
                        }
                        
                        // Try to get cached video first
                        if let cachedData = parent.viewModel.getCachedVideo(for: pin.videoURL),
                           let cachedURL = try? await saveTempVideo(data: cachedData) {
                            loadingAlert.dismiss(animated: true)
                            await playVideo(from: cachedURL)
                            return
                        }
                        
                        // Create an asset and preload it
                        let asset = AVURLAsset(url: videoURL)
                        _ = try await asset.load(.isPlayable)
                        
                        // Cache the video data for future use
                        if let url = URL(string: pin.videoURL) {
                            try? await parent.viewModel.cacheVideo(from: url, key: pin.videoURL)
                        }
                        
                        loadingAlert.dismiss(animated: true)
                        
                        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
                        let playerViewController = AVPlayerViewController()
                        playerViewController.player = player
                        
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootViewController = windowScene.windows.first?.rootViewController,
                           rootViewController.presentedViewController == loadingAlert {
                            rootViewController.dismiss(animated: true) {
                                rootViewController.present(playerViewController, animated: true) {
                                    player.play()
                                }
                            }
                        }
                    } catch let error as NSError {
                        // Dismiss loading alert if present
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootViewController = windowScene.windows.first?.rootViewController {
                            rootViewController.dismiss(animated: true)
                        }
                        
                        // Handle specific error cases
                        switch error.domain {
                        case AVFoundationErrorDomain:
                            parent.viewModel.showError("Video playback error: The video format is not supported")
                        case NSURLErrorDomain:
                            parent.viewModel.showError("Network error: Please check your connection and try again")
                        default:
                            parent.viewModel.showError("Failed to load video: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
        
        private func saveTempVideo(data: Data) async throws -> URL {
            do {
                let tempDir = FileManager.default.temporaryDirectory
                let tempFile = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
                try data.write(to: tempFile)
                print("Saved temporary video file: \(tempFile.path)")
                return tempFile
            } catch {
                print("Failed to save temporary video: \(error)")
                throw error
            }
        }
        
        private func playVideo(from url: URL) async {
            do {
                // Check if there's already a video being presented
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController,
                   rootViewController.presentedViewController != nil {
                    // Dismiss any existing presentation first
                    await withCheckedContinuation { continuation in
                        rootViewController.dismiss(animated: true) {
                            continuation.resume()
                        }
                    }
                }
                
                // Create an asset and preload it
                let asset = AVURLAsset(url: url)
                
                // Check if video is playable using the new API
                if #available(iOS 16.0, *) {
                    let isPlayable = try await asset.load(.isPlayable)
                    guard isPlayable else {
                        parent.viewModel.showError("This video cannot be played")
                        return
                    }
                } else {
                    // Fallback for iOS 15 and earlier
                    let playableKey = "playable"
                    await asset.loadValues(forKeys: [playableKey])
                    guard asset.isPlayable else {
                        parent.viewModel.showError("This video cannot be played")
                        return
                    }
                }
                
                // Create player and view controller
                let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
                let playerViewController = AVPlayerViewController()
                playerViewController.player = player
                
                // Configure player
                player.actionAtItemEnd = .pause
                
                // Present player
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    
                    // Add loading indicator to player view
                    let loadingIndicator = UIActivityIndicatorView(style: .large)
                    loadingIndicator.color = .white
                    playerViewController.view.addSubview(loadingIndicator)
                    loadingIndicator.center = playerViewController.view.center
                    loadingIndicator.startAnimating()
                    
                    // Present the player
                    await withCheckedContinuation { continuation in
                        rootViewController.present(playerViewController, animated: true) {
                            // Start playing when ready
                            player.play()
                            continuation.resume()
                        }
                    }
                    
                    // Store observation token to prevent premature deallocation
                    let observation = player.currentItem?.observe(\.status) { [weak self] item, _ in
                        DispatchQueue.main.async {
                            if item.status == .readyToPlay {
                                loadingIndicator.stopAnimating()
                                loadingIndicator.removeFromSuperview()
                            } else if item.status == .failed {
                                self?.parent.viewModel.showError("Failed to play video: \(item.error?.localizedDescription ?? "Unknown error")")
                            }
                        }
                    }
                    
                    // Store observation token in associated object to keep it alive
                    if let observation = observation {
                        objc_setAssociatedObject(playerViewController, "statusObservation", observation, .OBJC_ASSOCIATION_RETAIN)
                    }
                }
            } catch {
                parent.viewModel.showError("Failed to play video: \(error.localizedDescription)")
            }
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async {
                if let currentRegion = self.parent.viewModel.mapRegion,
                   (currentRegion.center.latitude != mapView.region.center.latitude ||
                    currentRegion.center.longitude != mapView.region.center.longitude ||
                    currentRegion.span.latitudeDelta != mapView.region.span.latitudeDelta ||
                    currentRegion.span.longitudeDelta != mapView.region.span.longitudeDelta) {
                    self.parent.viewModel.mapRegion = mapView.region
                }
            }
        }
    }
}
