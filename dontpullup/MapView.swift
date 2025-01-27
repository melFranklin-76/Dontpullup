import SwiftUI
import MapKit
import AVKit

class PinAnnotation: MKPointAnnotation {
    let pin: Pin
    
    init(pin: Pin) {
        self.pin = pin
        super.init()
        self.coordinate = pin.coordinate
        self.title = pin.incidentType.emoji
    }
}

struct MapView: UIViewRepresentable {
    @ObservedObject var viewModel: MapViewModel
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        
        // Register annotation view
        mapView.register(
            MKMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier
        )
        
        // Optimize map performance
        mapView.isPitchEnabled = false // Disable 3D view to reduce rendering load
        mapView.isRotateEnabled = false // Disable rotation to reduce complexity
        if mapView.responds(to: NSSelectorFromString("setPreferredFramesPerSecond:")) {
            mapView.setValue(30, forKey: "preferredFramesPerSecond")
        }
        
        // Add gesture recognizer
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPress)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        Task { @MainActor in
            // Update map type first to prevent style loading issues
            if mapView.mapType != viewModel.mapType {
                mapView.mapType = viewModel.mapType
            }
            
            // Update annotations efficiently
            let currentAnnotations = mapView.annotations.compactMap { $0 as? PinAnnotation }
            let newPins = viewModel.filteredPins
            
            // Remove annotations that are no longer in filtered pins
            let annotationsToRemove = currentAnnotations.filter { annotation in
                !newPins.contains { $0.id == annotation.pin.id }
            }
            mapView.removeAnnotations(annotationsToRemove)
            
            // Add new annotations
            let existingPinIds = currentAnnotations.map { $0.pin.id }
            let newAnnotations = newPins
                .filter { !existingPinIds.contains($0.id) }
                .map { PinAnnotation(pin: $0) }
            mapView.addAnnotations(newAnnotations)
            
            // Update region if needed
            if let newRegion = viewModel.mapRegion {
                mapView.setRegion(newRegion, animated: true)
                viewModel.mapRegion = nil // Clear the region update
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
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            
            if let pinAnnotation = annotation as? PinAnnotation {
                let identifier = "EmojiAnnotation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = false
                } else {
                    annotationView?.annotation = annotation
                }
                
                // Customize pin appearance
                annotationView?.glyphText = pinAnnotation.pin.incidentType.emoji
                annotationView?.markerTintColor = .clear
                annotationView?.glyphTintColor = .black
                
                return annotationView
            }
            
            return nil
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
                            mapView.removeAnnotation(annotation)
                        } catch {
                            parent.viewModel.showError(error.localizedDescription)
                        }
                    } else {
                        parent.viewModel.showError("You can only delete your own pins")
                    }
                }
            } else {
                // Play video immediately
                if let videoURL = URL(string: pin.videoURL) {
                    Task { @MainActor in
                        do {
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
                               let rootViewController = windowScene.windows.first?.rootViewController {
                                rootViewController.present(playerViewController, animated: true) {
                                    player.play()
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
        }
        
        private func saveTempVideo(data: Data) async throws -> URL {
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
            try data.write(to: tempFile)
            return tempFile
        }
        
        private func playVideo(from url: URL) async {
            let player = AVPlayer(url: url)
            let playerViewController = AVPlayerViewController()
            playerViewController.player = player
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(playerViewController, animated: true) {
                    player.play()
                }
            }
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Update region on next runloop to avoid view update conflicts
            let newRegion = mapView.region
            DispatchQueue.main.async {
                self.parent.viewModel.mapRegion = newRegion
            }
        }
    }
} 
