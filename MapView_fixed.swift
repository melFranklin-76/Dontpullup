// This is a fixed version of the mapView(_:didSelect:) method from MapView.swift

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
    
    // Play video logic refactored
    Task { @MainActor in
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