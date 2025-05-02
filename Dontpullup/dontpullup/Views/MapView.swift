import SwiftUI
import MapKit
import AVKit
import Combine // Import Combine
import CoreLocation
import AudioToolbox

// Update the constants to be more specific and avoid naming conflicts
private enum MapViewConstants {
    static let pinDropLimit: CLLocationDistance = 200 * 0.3048 // 200 feet in meters
    static let defaultSpan = MKCoordinateSpan(
        latitudeDelta: pinDropLimit / 111000 * 2.5, // Convert meters to degrees with some padding
        longitudeDelta: pinDropLimit / 111000 * 2.5
    )
    static let minZoomDistance: CLLocationDistance = 100
    static let maxZoomDistance: CLLocationDistance = 50000
    static let defaultAltitude: CLLocationDistance = 1000
    
    // Add minimum span to prevent over-zooming
    static let minSpan = MKCoordinateSpan(
        latitudeDelta: defaultSpan.latitudeDelta * 0.8,
        longitudeDelta: defaultSpan.longitudeDelta * 0.8
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

struct MapView: View {
    @EnvironmentObject private var viewModel: MapViewModel
    @EnvironmentObject private var authState: AuthState
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var selectedPin: Pin?
    @State private var showingVideoPlayer = false
    @State private var videoURLToPlay: URL?
    @State private var showingSettings = false
    @State private var showingProfile = false
    @State private var errorState = false
    @State private var errorMessage = ""
    
    // Onboarding State
    @AppStorage("hasCompletedMapOnboarding") var hasCompletedOnboarding = false
    @State private var currentOnboardingStep = 0
    private let onboardingInstructions: [String] = [
        "Tap any indicator to watch its attached video 📢 👊 ☎️. Drag to explore communities.",
        "To share your experience, long-press within 200 ft of your location & choose a video (max 3 min).",
        "Press 📱 to show only your pins. Use ✏️ to delete your pins (enter/exit edit mode).",
        "Press 📢 for verbal incidents, 👊 physical incidents, ☎️ for emergency incidents.",
        "Use ➕ and ➖ to zoom the map. Press 🗺️ to change map style.",
        "Press 📍 to center the map on your current location.",
        "Press ❓ for Help & Guidelines. Press ⚙️ for Settings & Info.",
        "Press 👤 to view your account and profile options.",
        "Upload progress shows in the center of screen. Pins update automatically."
    ]
    
    var body: some View {
        GeometryReader { geometry in
            // Single ZStack that contains everything
            ZStack {
                // Base map layer
                MapViewInternal(viewModel: viewModel)
                    .edgesIgnoringSafeArea(.all)
                
                // Add all control overlays
                
                // 1. Filter buttons (right side)
                VStack {
                    Spacer()
                    // Use adaptive spacing based on size class
                    let filterButtonSpacing: CGFloat = horizontalSizeClass == .regular ? 18 : 12
                    VStack(spacing: filterButtonSpacing) {
                        ForEach(IncidentType.allCases, id: \.self) { type in
                            filterButton(for: type, size: geometry.size)
                        }
                        
                        // Device-specific pins filter button (shows only my pins)
                        Button(action: {
                            HapticManager.feedback(.medium)
                            viewModel.toggleMyPinsFilter()
                        }) {
                            ZStack {
                                let baseSize: CGFloat = horizontalSizeClass == .regular ? 48 : 44
                                let adjustedSize = baseSize * 0.9
                                let baseFont: CGFloat = horizontalSizeClass == .regular ? 24 : 20
                                let adjustedFont = baseFont * 0.9
                                
                                Circle()
                                    .fill(viewModel.showingOnlyMyPins ? Color.blue : Color.gray.opacity(0.5))
                                    .frame(width: adjustedSize, height: adjustedSize)
                                
                                Text("📱")
                                    .font(.system(size: adjustedFont))
                            }
                        }
                    }
                    .padding(.trailing, horizontalSizeClass == .regular ? 24 : 16)
                    .offset(y: -geometry.size.height * 0.25) // elevate stack ~25% screen height
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .trailing) // Right align
                
                // 2. Zoom controls (Bottom right)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            let zoomButtonSize: CGFloat = horizontalSizeClass == .regular ? 50 : 40
                            Button(action: { viewModel.zoomIn() }) {
                                Image(systemName: "plus.magnifyingglass")
                                    .font(.system(size: horizontalSizeClass == .regular ? 24 : 20))
                                    .foregroundColor(.white)
                                    .frame(width: zoomButtonSize, height: zoomButtonSize)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            Button(action: { viewModel.zoomOut() }) {
                                Image(systemName: "minus.magnifyingglass")
                                    .font(.system(size: horizontalSizeClass == .regular ? 24 : 20))
                                    .foregroundColor(.white)
                                    .frame(width: zoomButtonSize, height: zoomButtonSize)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 60)
                    }
                }
                
                // 3. Bottom navigation controls
                VStack {
                    Spacer()
                    let bottomControlSize: CGFloat = horizontalSizeClass == .regular ? 54 : 44
                    let bottomControlSpacing: CGFloat = horizontalSizeClass == .regular ? 24 : 16
                    
                    HStack(spacing: bottomControlSpacing) {
                        Button(action: {
                            HapticManager.feedback(.medium)
                            viewModel.showingHelp = true
                        }) {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.system(size: horizontalSizeClass == .regular ? 28 : 24))
                                .foregroundColor(.white)
                                .frame(width: bottomControlSize, height: bottomControlSize)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        
                        // Settings Button
                        Button(action: {
                            HapticManager.feedback(.medium)
                            showingSettings = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: horizontalSizeClass == .regular ? 28 : 24))
                                .foregroundColor(.white)
                                .frame(width: bottomControlSize, height: bottomControlSize)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        
                        // Map Type Button
                        Button(action: {
                            HapticManager.feedback(.medium)
                            viewModel.toggleMapType()
                        }) {
                            Image(systemName: "map.fill")
                                .font(.system(size: horizontalSizeClass == .regular ? 28 : 24))
                                .foregroundColor(.white)
                                .frame(width: bottomControlSize, height: bottomControlSize)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        // Center Location Button
                        Button(action: {
                            HapticManager.feedback(.medium)
                            viewModel.centerOnUserLocation()
                        }) {
                            Image(systemName: "location.fill")
                                .font(.system(size: horizontalSizeClass == .regular ? 28 : 24))
                                .foregroundColor(.white)
                                .frame(width: bottomControlSize, height: bottomControlSize)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        
                        // Edit Mode Button
                        Button(action: {
                            HapticManager.feedback(.medium)
                            viewModel.toggleEditMode()
                        }) {
                            Image(systemName: viewModel.isEditMode ? "xmark.circle.fill" : "pencil.circle.fill")
                                .font(.system(size: horizontalSizeClass == .regular ? 28 : 24))
                                .foregroundColor(viewModel.isEditMode ? .red : .white)
                                .frame(width: bottomControlSize, height: bottomControlSize)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        
                        // Profile Button
                        Button(action: {
                            HapticManager.feedback(.medium)
                            showingProfile = true
                        }) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: horizontalSizeClass == .regular ? 28 : 24))
                                .foregroundColor(.white)
                                .frame(width: bottomControlSize, height: bottomControlSize)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 12)
                    .padding(.bottom, horizontalSizeClass == .regular ? 10 : 4)
                }
                
                // Onboarding overlay
                if !hasCompletedOnboarding && currentOnboardingStep < onboardingInstructions.count {
                    Color.black.opacity(0.5)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            print("Onboarding tap detected - trying all haptic types")
                            
                            let directGenerator = UIImpactFeedbackGenerator(style: .heavy)
                            directGenerator.prepare()
                            directGenerator.impactOccurred(intensity: 1.0)
                            
                            HapticManager.selection()
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                HapticManager.forceFeedback()
                            }
                            
                            currentOnboardingStep += 1
                            if currentOnboardingStep >= onboardingInstructions.count {
                                hasCompletedOnboarding = true
                            }
                        }
                    
                    VStack {
                        Spacer()
                        Text(onboardingInstructions[currentOnboardingStep])
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(-2)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(12)
                            .shadow(radius: 8)
                            .frame(maxWidth: UIScreen.main.bounds.width * 0.75)
                            .padding(.bottom, 60)
                            .offset(x: -UIScreen.main.bounds.width * 0.12)

                        Text("Tap anywhere to continue (\(currentOnboardingStep + 1)/\(onboardingInstructions.count))")
                             .font(.caption2)
                             .foregroundColor(.white.opacity(0.8))
                             .padding(.bottom, 10)
                             .offset(x: -UIScreen.main.bounds.width * 0.12)
                             
                        Button(action: {
                            AudioServicesPlaySystemSound(1519)
                            hasCompletedOnboarding = true
                        }) {
                            Text("Skip All")
                                .font(.footnote)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.6))
                                .cornerRadius(16)
                        }
                        .padding(.bottom, 30)
                        .offset(x: -UIScreen.main.bounds.width * 0.12)

                        Spacer()
                    }
                    .transition(.opacity.animation(.easeInOut))
                }

                // Progress indicator for uploads
                if viewModel.isUploading {
                    GeometryReader { geo in
                        VStack {
                            Text("Uploading Video...")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            ProgressView(value: viewModel.uploadProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                .padding(.horizontal, 6)
                                .frame(width: 180)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .frame(width: 200, height: 80)
                        .position(x: geo.size.width/2, y: geo.size.height/2)
                        .transition(.opacity)
                    }
                }
            }
        }
        .ignoresSafeArea(.all)
        .onAppear {
            print("MapView appeared - centering on user location")
            viewModel.centerOnUserLocation()
        }
        .fullScreenCover(isPresented: $showingVideoPlayer) {
            if let url = videoURLToPlay {
                VideoPlayerView(videoURL: url)
                    .edgesIgnoringSafeArea(.all)
                    .onDisappear {
                        Task {
                            try? FileManager.default.removeItem(at: url)
                            print("Cleaned up temporary video file: \(url.path)")
                        }
                    }
            }
        }
        .sheet(isPresented: $viewModel.showingIncidentPicker) {
            IncidentTypePicker(viewModel: viewModel)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(authState)
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView()
                .environmentObject(authState)
        }
        .sheet(isPresented: $viewModel.showingHelp) {
            HelpView()
        }
        .alert(viewModel.alertMessage ?? "An error occurred", isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) {
                HapticManager.feedback(.light)
            }
        }
    }
    
    // Helper function for filter buttons
    private func filterButton(for type: IncidentType, size: CGSize) -> some View {
        let isSelected = Task { @MainActor in
            await viewModel.isFilterActive(type)
        }
        
        return Button(action: {
            HapticManager.feedback(.medium)
            viewModel.toggleFilter(type)
        }) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: horizontalSizeClass == .regular ? 48 : 44, height: horizontalSizeClass == .regular ? 48 : 44)
                
                Text(type.emoji)
                    .font(.system(size: horizontalSizeClass == .regular ? 24 : 20))
            }
            .overlay(
                Circle()
                    .stroke(Color.blue, lineWidth: 2)
                    .opacity(Task { @MainActor in await viewModel.isFilterActive(type) }.value ? 1 : 0)
            )
        }
    }
}

struct MapViewInternal: UIViewRepresentable {
    @ObservedObject var viewModel: MapViewModel
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        context.coordinator.mapView = mapView
        
        // Ensure the map fills the entire area
        mapView.frame = UIScreen.main.bounds
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Ensure user location shows
        mapView.showsUserLocation = true
        
        // Configure map appearance
        MapStyleManager.applyCustomStyle(to: mapView)
        
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
        
        // Set initial region immediately, don't wait for async location
        if let region = viewModel.mapRegion {
            // Use the existing region if available
            mapView.setRegion(region, animated: false)
        } else {
            // Set a default region to ensure map appears immediately
            let fallbackRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // San Francisco
                span: MapViewConstants.defaultSpan
            )
            mapView.setRegion(fallbackRegion, animated: false)
            
            // Try to get actual location and update if available
            Task { @MainActor in
                if let location = await viewModel.getCurrentLocation() {
                    let region = MKCoordinateRegion(
                        center: location.coordinate,
                        span: MapViewConstants.defaultSpan
                    )
                    mapView.setRegion(region, animated: true)
                }
            }
        }
        
        // Add gesture recognizer
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPress)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update map type with animation if needed
        if mapView.mapType != viewModel.mapType {
            UIView.animate(withDuration: 0.3) {
                mapView.mapType = viewModel.mapType
                // Avoid overriding interface style; can block tile rendering on some simulator runtimes.
                // mapView.overrideUserInterfaceStyle = .dark
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
        
        // Update region if needed and enforce minimum zoom
        if let newRegion = viewModel.mapRegion {
            let enforcedSpan = MKCoordinateSpan(
                latitudeDelta: max(newRegion.span.latitudeDelta, MapViewConstants.minSpan.latitudeDelta),
                longitudeDelta: max(newRegion.span.longitudeDelta, MapViewConstants.minSpan.longitudeDelta)
            )
            
            let region = MKCoordinateRegion(
                center: newRegion.center,
                span: enforcedSpan
            )
            
            // Only update region if it's significantly different
            let currentCenter = mapView.region.center
            let newCenter = region.center
            let distance = MKMapPoint(currentCenter).distance(to: MKMapPoint(newCenter))
            
            if distance > 100 || // If centers are more than 100 points apart
               abs(mapView.region.span.latitudeDelta - region.span.latitudeDelta) > 0.01 {
                mapView.setRegion(region, animated: true)
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
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewInternal
        weak var mapView: MKMapView? // Add weak reference to the map view
        private var cancellables = Set<AnyCancellable>() // Store subscriptions
        
        init(_ parent: MapViewInternal) {
            self.parent = parent
            super.init()
            
            // Subscribe to ViewModel's zoom subjects
            parent.viewModel.zoomInSubject
                .sink { [weak self] in
                    self?.zoomIn()
                }
                .store(in: &cancellables)
                
            parent.viewModel.zoomOutSubject
                .sink { [weak self] in
                    self?.zoomOut()
                }
                .store(in: &cancellables)
        }
        
        // Add zoom functions to Coordinator
        func zoomIn() {
            guard let mapView = mapView else { return }
            var region = mapView.region
            // Prevent zooming in too far by clamping the span
            let newLatitudeDelta = max(region.span.latitudeDelta / 2, MapViewConstants.minSpan.latitudeDelta * 0.5) // Allow slightly more zoom than minSpan
            let newLongitudeDelta = max(region.span.longitudeDelta / 2, MapViewConstants.minSpan.longitudeDelta * 0.5)
            region.span = MKCoordinateSpan(latitudeDelta: newLatitudeDelta, longitudeDelta: newLongitudeDelta)
            mapView.setRegion(region, animated: true)
        }
        
        func zoomOut() {
            guard let mapView = mapView else { return }
            var region = mapView.region
            // Prevent zooming out too far (optional, could use cameraZoomRange)
            region.span = MKCoordinateSpan(latitudeDelta: region.span.latitudeDelta * 2, longitudeDelta: region.span.longitudeDelta * 2)
            mapView.setRegion(region, animated: true)
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
                    if await parent.viewModel.userCanEditPin(pin) {
                        do {
                            print("Attempting to delete pin: \(pin.id)")
                            try await parent.viewModel.deletePin(pin)
                            // Add deletion animation
                            UIView.animate(withDuration: 0.3, animations: {
                                view.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
                                view.alpha = 0
                            }) { _ in
                                mapView.removeAnnotation(annotation)
                                print("Pin deleted and removed from map: \(pin.id)")
                            }
                        } catch {
                            print("Error deleting pin: \(error.localizedDescription)")
                            parent.viewModel.showError(error.localizedDescription)
                        }
                    } else {
                        print("User cannot edit pin: \(pin.id)")
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
                    
                    // Present loading alert and wait for presentation to likely settle (small delay)
                    // Using await on present isn't standard, so use a small Task.sleep or rely on animation timing.
                    // Alternatively, present it without awaiting completion here if confident dismiss works.
                    rootVC.present(loadingAlert!, animated: true)
                    isLoadingIndicatorPresented = true
                    // Optional: Add a tiny sleep if presentation races are suspected, though usually not needed.
                    // try? await Task.sleep(nanoseconds: 100_000_000) 

                    // --- Video Fetching/Caching Logic --- 
                    if let cachedData = parent.viewModel.getCachedVideo(for: pin.videoURL) {
                        print("Playing video from cache...")
                        videoURLToPlay = try createTemporaryFile(from: cachedData)
                    } else if let remoteURL = URL(string: pin.videoURL) { 
                        print("Video not cached. Downloading...")
                        try await parent.viewModel.cacheVideo(from: remoteURL, key: pin.videoURL)
                        if let newlyCachedData = parent.viewModel.getCachedVideo(for: pin.videoURL) {
                             print("Playing newly cached video...")
                             videoURLToPlay = try createTemporaryFile(from: newlyCachedData)
                        } else {
                             throw NSError(domain: "VideoPlayback", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve video after caching attempt."])
                        }
                    } else {
                        throw NSError(domain: "VideoPlayback", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid video URL string."])
                    }
                    // --- End Video Fetching --- 

                    // Ensure loading indicator is dismissed and wait for dismissal to complete
                    if isLoadingIndicatorPresented {
                        await dismissViewController(loadingAlert, animated: true)
                        isLoadingIndicatorPresented = false
                        loadingAlert = nil // Release reference
                    }

                    // Play the video if we have a URL
                    if let url = videoURLToPlay {
                        // Pass the selected pin to the playVideo function
                        await playVideo(from: url, for: pin) 
                    } else {
                         throw NSError(domain: "VideoPlayback", code: -3, userInfo: [NSLocalizedDescriptionKey: "Could not obtain a valid URL to play."])
                    }

                } catch { 
                    print("Error during video playback sequence: \(error)")
                    // Ensure loading is dismissed on error
                    if isLoadingIndicatorPresented, let alertToDismiss = loadingAlert {
                         await dismissViewController(alertToDismiss, animated: true)
                    }
                    parent.viewModel.showError("Failed to load video: \(error.localizedDescription)") 
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
            
            // Use continuation to bridge completion handler
            await withCheckedContinuation { continuation in
                vc.dismiss(animated: animated) {
                    continuation.resume()
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
        
        // playVideo function refined - now accepts a Pin
        private func playVideo(from url: URL, for pin: Pin) async {
            do {
                // Assume caller handled dismissing previous VCs
                
                // 1. Create Asset from temp URL
                let asset = AVURLAsset(url: url)

                // 2. Load essential properties asynchronously *before* creating PlayerItem
                // Remove unused key definitions
                // let loadableKeys: [AVAsyncProperty<AVURLAsset, CMTime>] = [.duration]
                // let tracksKey: AVAsyncProperty<AVURLAsset, [AVAssetTrack]> = .tracks
                
                // Check duration first (optional, but can filter invalid assets early)
                 let duration = try await asset.load(.duration)
                 guard duration.seconds > 0 else {
                     throw NSError(domain: "VideoPlayback", code: -10, userInfo: [NSLocalizedDescriptionKey: "Video asset has invalid duration."])
                 }

                // Load tracks (important for player setup)
                let tracks = try await asset.loadTracks(withMediaType: .video)
                guard !tracks.isEmpty else {
                     throw NSError(domain: "VideoPlayback", code: -11, userInfo: [NSLocalizedDescriptionKey: "Video asset has no video tracks."])
                }
                
                // Optional: Re-check isPlayable if needed, though loading tracks often suffices
                // let isPlayable = try await asset.load(.isPlayable)
                // guard isPlayable else { throw ... }

                // 3. Create PlayerItem *after* loading asset properties
                let playerItem = AVPlayerItem(asset: asset) 

                // 4. Setup Player and ViewController
                let player = AVPlayer(playerItem: playerItem)
                let playerViewController = AVPlayerViewController()
                playerViewController.player = player
                player.actionAtItemEnd = .pause
                
                // --- Add Report Button Overlay ---
                let reportOverlayView = ReportButtonOverlay(viewModel: parent.viewModel, pin: pin) {
                    // Dismiss the player when report button is tapped
                    playerViewController.dismiss(animated: true)
                }
                let hostingController = UIHostingController(rootView: reportOverlayView)
                hostingController.view.backgroundColor = .clear // Make background transparent
                
                // Add the hosting controller as a child VC and its view as a subview
                playerViewController.addChild(hostingController)
                playerViewController.view.addSubview(hostingController.view)
                hostingController.didMove(toParent: playerViewController)

                hostingController.view.translatesAutoresizingMaskIntoConstraints = false // Use Auto Layout

                // Calculate the optimal size for the SwiftUI view
                let fittingSize = hostingController.sizeThatFits(in: playerViewController.view.bounds.size)

                // Activate constraints to position the overlay (e.g., bottom trailing corner)
                // Constrain the overlay view to the player VC's safe area
                let safeArea = playerViewController.view.safeAreaLayoutGuide
                NSLayoutConstraint.activate([
                    hostingController.view.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -20),
                    hostingController.view.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -20),
                    // Add explicit size constraints based on the SwiftUI content
                    hostingController.view.widthAnchor.constraint(equalToConstant: fittingSize.width),
                    hostingController.view.heightAnchor.constraint(equalToConstant: fittingSize.height)
                ])
                // --- End Overlay ---

                guard let rootVC = getRootViewController() else {
                    print("Error: Cannot present player, root VC not found.")
                    try? FileManager.default.removeItem(at: url) // Clean up temp file
                    return
                }
                     
                // 5. Present player and wait for completion
                try await presentViewController(playerViewController, on: rootVC, animated: true)
                player.play() // Play after presentation completes

                // 6. Setup temporary file cleanup observer (remains the same)
                NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, 
                                                   object: playerItem,
                                                   queue: .main) { _ in 
                    print("Player item finished playing. Cleaning up temp file: \(url.path)")
                    try? FileManager.default.removeItem(at: url)
                }
                
            } catch { // Catch errors from asset loading or presentation
                parent.viewModel.showError("Failed to play video: \(error.localizedDescription)")
                try? FileManager.default.removeItem(at: url) // Clean up temp file on error
            }
        }
        
        // Generic helper to present a view controller and wait for completion
        private func presentViewController(_ viewControllerToPresent: UIViewController, on presentingViewController: UIViewController, animated: Bool) async throws {
            // Use continuation to bridge completion handler and handle potential errors
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                presentingViewController.present(viewControllerToPresent, animated: animated) {
                    // Check if the presentation actually succeeded if possible (though usually completion implies success)
                    // If presentation could fail silently, more checks might be needed here.
                    continuation.resume()
                }
            }
            print("Presentation completion handler executed for \(type(of: viewControllerToPresent))") // Debug log
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

// --- SwiftUI Overlay View Definition ---
struct ReportButtonOverlay: View {
    @ObservedObject var viewModel: MapViewModel
    let pin: Pin
    let dismissAction: () -> Void // Action to dismiss the player
    
    @State private var showingReportSheet = false
    
    var body: some View {
        Button {
            showingReportSheet = true
        } label: {
            Label("Report", systemImage: "flag.fill")
                .padding(8)
                .background(.ultraThinMaterial) // Use a material background for visibility
                .foregroundColor(.red)
                .clipShape(Capsule())
                .shadow(radius: 3)
        }
        // Ensure the button itself doesn't expand unnecessarily
        .fixedSize()
        .sheet(isPresented: $showingReportSheet) {
            ReportFormView(pin: pin, viewModel: viewModel, isPresented: $showingReportSheet, dismissPlayer: dismissAction)
        }
    }
}
// --- End Overlay View Definition ---

// Form for collecting report details
struct ReportFormView: View {
    let pin: Pin
    @ObservedObject var viewModel: MapViewModel
    @Binding var isPresented: Bool
    let dismissPlayer: () -> Void
    
    @State private var reporterEmail = ""
    @State private var reportReason = ""
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var emailFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Report Information")) {
                    TextField("Your Email (Optional)", text: $reporterEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($emailFieldFocused)
                    
                    Picker("Reason", selection: $reportReason) {
                        Text("Select a reason").tag("")
                        Text("Inappropriate content").tag("inappropriate")
                        Text("Misleading information").tag("misleading")
                        Text("Spam").tag("spam")
                        Text("Other").tag("other")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: reportReason) { _ in
                        if !reportReason.isEmpty {
                            HapticManager.selection() // Feedback when selecting a reason
                        }
                    }
                }
                
                Section {
                    VStack(spacing: 10) {
                        Button(action: submitReport) {
                            HStack {
                                Spacer()
                                if isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .padding(.trailing, 10)
                                } else {
                                    Text("Submit Report")
                                        .foregroundColor(.white)
                                        .bold()
                                }
                                Spacer()
                            }
                        }
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .cornerRadius(8)
                        .disabled(isSubmitting || reportReason.isEmpty)
                        
                        // Add a more prominent Cancel button
                        Button(action: cancel) {
                            HStack {
                                Spacer()
                                Text("Cancel")
                                    .foregroundColor(.white)
                                    .bold()
                                Spacer()
                            }
                        }
                        .padding(.vertical, 10)
                        .background(Color.gray)
                        .cornerRadius(8)
                        .disabled(isSubmitting)
                    }
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Report Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        cancel()
                    }
                    .foregroundColor(.white)
                }
            })
            .onAppear {
                // Focus the email field on appear
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    emailFieldFocused = true
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {
                    // Close the sheet if there's an error
                    if !isSubmitting {
                        closeAllSheets()
                    }
                }
            } message: {
                Text(errorMessage)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func submitReport() {
        guard !reportReason.isEmpty else {
            HapticManager.error() // Error feedback
            errorMessage = "Please select a reason for reporting"
            showError = true
            return
        }
        
        HapticManager.feedback(.medium) // Feedback when starting submission
        isSubmitting = true
        
        // Call viewModel with the additional info
        viewModel.reportPin(pin, email: reporterEmail, reason: reportReason) { success in
            isSubmitting = false
            
            if success {
                HapticManager.success() // Success feedback
                // Successfully submitted, close all sheets
                closeAllSheets()
            } else {
                HapticManager.error() // Error feedback
                // Show error if submission failed
                errorMessage = "Failed to submit report. Please try again."
                showError = true
            }
        }
    }
    
    private func cancel() {
        // Only allow cancellation if not currently submitting
        if !isSubmitting {
            HapticManager.feedback(.light) // Light feedback for cancel
            isPresented = false
        }
    }
    
    private func closeAllSheets() {
        // First close the report form
        isPresented = false
        
        // Then dismiss the player after a slight delay to ensure smooth dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismissPlayer()
        }
    }
}

// Simple Video Player View (Example)
struct VideoPlayerView: View {
    let videoURL: URL

    var body: some View {
        let player = AVPlayer(url: videoURL)
        VideoPlayer(player: player)
            .onAppear {
                player.play()
            }
            .onDisappear {
                player.pause()
            }
    }
} 
