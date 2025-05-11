# Simplified Pin Reporting Flow Integration Plan

## Overview
This document outlines how to implement the simplified reporting process where a user can long-press on the map to drop a pin, select an incident type, choose a video from their photo library, and have the pin appear on the map in real-time.

## Implementation Steps

### 1. Update `MapView.swift` Coordinator Class

```swift
// In MapView.swift Coordinator class
@objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
    // Respond to long-press only when NOT in delete-edit mode
    guard gesture.state == .began, parent.viewModel.isEditMode == false else { return }
    
    let point = gesture.location(in: gesture.view)
    let coordinate = (gesture.view as? MKMapView)?.convert(point, toCoordinateFrom: gesture.view)
    
    guard let validCoordinate = coordinate else { return }
    
    // Check if user is authenticated
    guard let currentUserId = Auth.auth().currentUser?.uid else {
        parent.viewModel.showError("You need to sign in to drop pins")
        return
    }
    
    // Check location validity
    Task { @MainActor in
        do {
            let locationValid = await parent.viewModel.isWithinPinDropRange(coordinate: validCoordinate)
            if !locationValid {
                parent.viewModel.showError("You can only drop pins within 200 feet of your location")
                return
            }
            
            // Start the simplified flow
            parent.handlePinDrop(at: validCoordinate)
        }
    }
}

// Add pin selection handler for edit mode
func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
    guard let annotation = view.annotation else { return }
    mapView.deselectAnnotation(annotation, animated: true)
    
    // Handle pin deletion in edit mode
    if let pinAnnotation = annotation as? PinAnnotation, parent.viewModel.isEditMode {
        let pin = pinAnnotation.pin
        
        // Verify the pin belongs to the current user
        if parent.viewModel.userCanEditPin(pin) {
            Task { @MainActor in
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
            }
        } else {
            parent.viewModel.showError("You can only delete your own pins")
        }
        return
    }
    
    // Handle regular pin tap (video playback) here
    // ...
}
```

### 2. Add Authentication Check to MapViewModel

```swift
// Add this to MapViewModel.swift

// Check if user can edit the pin (ownership check)
func userCanEditPin(_ pin: Pin) -> Bool {
    guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
    return pin.userId == currentUserId
}

// Toggle edit mode
func toggleEditMode() {
    if !isAuthenticated() {
        showAlert = true
        alertMessage = "Please sign in to edit pins"
        return
    }
    isEditMode.toggle()
}

// Check authentication status
private func isAuthenticated() -> Bool {
    return Auth.auth().currentUser != nil
}

// Toggle my pins filter
func toggleMyPinsFilter() {
    if !isAuthenticated() {
        showAlert = true
        alertMessage = "Please sign in to filter your pins"
        return
    }
    showingOnlyMyPins.toggle()
}
```

### 3. Update the Filter Implementation in MapViewModel

```swift
// Modified filtered pins computed property in MapViewModel.swift
var filteredPins: [Pin] {
    pins.filter { pin in
        if showingOnlyMyPins {
            guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
            return pin.userId == currentUserId
        }
        return selectedFilters.isEmpty || selectedFilters.contains(pin.incidentType)
    }
}
```

### 4. Add This to Your MapView Implementation

```swift
// Add these imports to MapView.swift
import PhotosUI
import AVKit
import UniformTypeIdentifiers
import FirebaseAuth

// Add this overlay to your map view
.overlay(
    Group {
        if viewModel.uploadProgress > 0 && viewModel.uploadProgress < 1.0 {
            UploadProgressView(viewModel: viewModel)
        }
    }
)
```

### 5. Implement "My Pins" Filter Button in MapContentView

```swift
// In the toolbar or filter section of your MapContentView
indicatorButton(emoji: "📱", action: {
    hapticImpact.impactOccurred()
    mapViewModel.toggleMyPinsFilter()
}, isSelected: mapViewModel.showingOnlyMyPins)
```

### 6. Implement Edit Mode Toggle in MapContentView

```swift
// In the toolbar or buttons section of your MapContentView
toolbarButton(
    systemName: mapViewModel.isEditMode ? "xmark.circle" : "pencil",
    action: {
        hapticImpact.impactOccurred()
        mapViewModel.toggleEditMode()
    },
    tint: mapViewModel.isEditMode ? .red : .white
)
```

## Testing the Flow

### Pin Creation
1. Sign in to the app (verify error message if not signed in)
2. Long-press on map within range of current location
3. Select incident type from the minimalist picker
4. Choose a video from the system Photos app
5. Verify the upload progress indicator appears non-intrusively
6. Confirm the pin appears on the map immediately after upload with correct emoji

### Pin Management and Filtering
1. Tap the cell phone emoji to show only your pins
2. Verify only your pins appear on the map
3. Tap the pencil icon to enter edit mode
4. Verify you can only delete your own pins
5. Tap a pin to delete it and verify it's removed from the map and Firestore
6. Tap the pencil icon again to exit edit mode

## Requirements Checklist

- [x] User must be signed in to drop pins
- [x] Long-press initiates the flow within 200ft of user location
- [x] Minimal incident type picker
- [x] Native iOS Photos picker for video selection
- [x] 3-minute maximum video duration enforcement
- [x] Non-blocking, minimal upload progress indicator
- [x] Real-time pin updates
- [x] User can filter to see only their own pins
- [x] User can delete only their own pins through edit mode
- [x] No multi-page wizards or confirmation screens
- [x] No custom camera interfaces 