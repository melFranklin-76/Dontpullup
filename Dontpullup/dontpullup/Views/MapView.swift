import SwiftUI
import MapKit
import AVKit
import Combine // Import Combine
import CoreLocation
import AudioToolbox
import CoreLocationUI // Required for LocationButton

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
    @StateObject private var viewModel: MapViewModel
    @EnvironmentObject var authState: AuthState
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    
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
    
    // Video Player State
    @State private var showingIncidentPicker = false
    @State private var newPinCoordinate: CLLocationCoordinate2D?

    init(mapViewModel: MapViewModel = MapViewModel()) {
        _viewModel = StateObject(wrappedValue: mapViewModel)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Map
                Map(coordinateRegion: $viewModel.region, showsUserLocation: true, annotationItems: viewModel.filteredPins) {
                    pin in
                    MapAnnotation(coordinate: pin.coordinate) {
                        PinAnnotationView(pin: pin, viewModel: viewModel) {
                            // Action to play video when pin annotation is tapped
                            Task {
                                await playVideo(for: pin)
                            }
                        }
                    }
                }
                .edgesIgnoringSafeArea(.top) // Extend map slightly above safe area if needed
                .accentColor(Color(.systemPink)) // Customize user location dot color
                .onAppear {
                    viewModel.checkIfLocationServicesIsEnabled()
                }
                .onLongPressGesture(minimumDuration: 0.5) { screenCoordinate in
                     guard authState.isUserAuthenticated == .signedIn && authState.currentUser != nil else {
                         viewModel.showAuthenticationRequiredAlert = true
                         return
                     }
                     let locationCoordinate = viewModel.convertScreenCoordinateToLocation(screenCoordinate: screenCoordinate, geometry: geometry)
                     // Check distance before showing picker
                     viewModel.checkDistanceAndPreparePin(coordinate: locationCoordinate) { isAllowed in
                         if isAllowed {
                             self.newPinCoordinate = locationCoordinate
                             self.showingIncidentPicker = true
                         }
                     }
                 }
                 .alert("Location Disabled", isPresented: $showLocationDisabledAlert) {
                     Button("OK") { }
                     Button("Settings") { // Button to open app settings
                         if let url = URL(string: UIApplication.openSettingsURLString) {
                             UIApplication.shared.open(url)
                         }
                     }
                 } message: {
                     Text("Location services are disabled. Please enable them in Settings to use map features.")
                 }
                 .alert("Error", isPresented: $viewModel.showErrorAlert, error: viewModel.activeError) {
                     Button("OK") { viewModel.activeError = nil } // Dismiss alert
                 }
                 .alert("Authentication Required", isPresented: $viewModel.showAuthenticationRequiredAlert) {
                     Button("OK") { }
                 } message: {
                     Text("You need to be logged in to drop a pin.")
                 }
                 .alert("Too Far", isPresented: $viewModel.showDistanceAlert) {
                      Button("OK") { }
                  } message: {
                      Text("You must be within 200 feet of your current location to drop a pin.")
                  }


                // Overlay UI Elements
                    VStack {
                    // Top Controls (Filters)
                    incidentFilterButtons(geometry: geometry)
                        .padding(.top, geometry.safeAreaInsets.top + 10) // Adjust top padding
                        .padding(.horizontal)

                    Spacer() // Pushes bottom controls down

                    // Bottom Right Controls (Zoom + Location)
                    bottomRightControls(geometry: geometry)

                     // Bottom Controls (Profile, Resources, Help)
                    bottomControls(geometry: geometry)
                }

                // Loading Indicator for video
                 if isLoadingVideo {
                     ProgressView("Loading Video...")
                         .progressViewStyle(CircularProgressViewStyle(tint: .white))
                         .padding()
                         .background(Color.black.opacity(0.6))
                                .foregroundColor(.white)
                        .cornerRadius(10)
                         .position(x: geometry.size.width / 2, y: geometry.size.height / 2) // Center on screen
                         .zIndex(1) // Ensure it's above other elements
                 }
            }
            // Video Player Sheet
            .sheet(isPresented: $showingVideoPlayer, onDismiss: stopVideo) {
                 if let player = videoPlayer {
                     VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)
                         .onAppear { player.play() } // Auto-play when sheet appears
                 } else {
                     // Placeholder or error view if video player couldn't be created
                     VStack {
                          Text("Could not load video.")
                          ProgressView()
                      }
                 }
             }
             // Incident Type Picker Sheet
             .sheet(isPresented: $showingIncidentPicker) {
                 IncidentTypePicker(selectedType: $viewModel.selectedIncidentTypeForNewPin) {
                     // Completion handler when a type is selected
                     if let coordinate = newPinCoordinate, let type = viewModel.selectedIncidentTypeForNewPin {
                          viewModel.uploadVideoAndCreatePin(coordinate: coordinate, incidentType: type)
                          showingIncidentPicker = false // Dismiss picker
                          newPinCoordinate = nil // Reset coordinate
                     }
                 }
             }
             .onChange(of: viewModel.locationManager.authorizationStatus) { _, newStatus in
                 if newStatus == .denied || newStatus == .restricted {
                     showLocationDisabledAlert = true
                 } else {
                     showLocationDisabledAlert = false
                 }
             }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func incidentFilterButtons(geometry: GeometryProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) { // Use compact spacing
                // Toggle All Button
                Button {
                    viewModel.toggleFilter(incidentType: .all)
                } label: {
                    filterButtonLabel(type: .all, isSelected: viewModel.activeFilters.contains(.all))
                }
                .buttonStyle(FilterButtonStyle(isSelected: viewModel.activeFilters.contains(.all)))

                // Buttons for each incident type
                ForEach(IncidentType.allCases.filter { $0 != .all && $0 != .none }) { type in
                    Button {
                        viewModel.toggleFilter(incidentType: type)
                    } label: {
                        filterButtonLabel(type: type, isSelected: viewModel.activeFilters.contains(type))
                    }
                    .buttonStyle(FilterButtonStyle(isSelected: viewModel.activeFilters.contains(type)))
                }
            }
            .padding(.horizontal) // Add padding within the scroll view
        }
        .frame(height: 44) // Use compact base size
    }

    @ViewBuilder
    private func filterButtonLabel(type: IncidentType, isSelected: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: type.iconName)
                .font(.system(size: 20)) // Use compact font size
            Text(type.rawValue)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func bottomRightControls(geometry: GeometryProxy) -> some View {
        VStack(spacing: 10) { // Use default spacing
            Button {
                viewModel.zoomIn()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(MapControlButton()) // Use style for consistency

            Button {
                viewModel.zoomOut()
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(MapControlButton())

            // Location Button - Use CoreLocationUI Button
             LocationButton(.currentLocation) {
                 viewModel.requestLocationUpdate()
             }
             .foregroundColor(.white)
             .cornerRadius(20) // Use compact size / 2
             .labelStyle(.iconOnly)
             .symbolVariant(.fill)
             .tint(colorScheme == .dark ? .gray.opacity(0.8) : .blue) // Adaptive tint
             .frame(width: 40, height: 40) // Use compact size
             .shadow(radius: 3)

        }
        .padding(.trailing, 16) // Use compact padding
        .padding(.bottom, geometry.safeAreaInsets.bottom + 60) // Adjusted padding
        .frame(maxWidth: .infinity, alignment: .trailing)
    }


    @ViewBuilder
    private func bottomControls(geometry: GeometryProxy) -> some View {
        HStack(spacing: 16) { // Use compact spacing
            Spacer()
            // Profile Button
            NavigationLink(destination: ProfileView()) {
                Image(systemName: "person.fill")
            }
            .buttonStyle(MapControlButton(size: 44)) // Use compact size

            // Resources Button
            NavigationLink(destination: ResourcesView()) {
                 Image(systemName: "list.bullet.clipboard.fill")
            }
            .buttonStyle(MapControlButton(size: 44))

            // Settings/Help Button (Example)
             NavigationLink(destination: HelpView()) { // Navigate to HelpView
                 Image(systemName: "questionmark.circle.fill")
             }
             .buttonStyle(MapControlButton(size: 44))

            Spacer()
        }
        .padding(.horizontal, 12) // Use compact horizontal padding
        .padding(.bottom, geometry.safeAreaInsets.bottom + 10) // Use compact bottom padding
        .frame(maxWidth: .infinity)
        .background(
             // Add a subtle gradient or blur background for better visibility
             LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.5)]), startPoint: .top, endPoint: .bottom)
                 .edgesIgnoringSafeArea(.bottom)
                 .frame(height: geometry.safeAreaInsets.bottom + 70) // Adjust height based on controls
                 .offset(y: geometry.safeAreaInsets.bottom + 30) // Adjust offset
         )
    }

    // MARK: - Helper Functions

    private func playVideo(for pin: Pin) async {
         guard let videoURLString = pin.videoURL else {
             viewModel.activeError = PinError.missingURL
             viewModel.showErrorAlert = true
                return
            }
            
         isLoadingVideo = true // Show loading indicator
         videoURLToPlay = await viewModel.fetchVideoURL(urlString: videoURLString)
         isLoadingVideo = false // Hide loading indicator

         guard let url = videoURLToPlay else {
             viewModel.activeError = PinError.urlCreationFailed // Or a more specific error
             viewModel.showErrorAlert = true
             return
         }

         videoPlayer = AVPlayer(url: url)
         showingVideoPlayer = true // Present the sheet
     }

    private func stopVideo() {
        videoPlayer?.pause()
        videoPlayer = nil
        videoURLToPlay = nil
        showingVideoPlayer = false
    }
}

// MARK: - Button Styles

struct FilterButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.blue : Color(.systemGray4))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct MapControlButton: ButtonStyle {
    var size: CGFloat = 40 // Default compact size
    var backgroundColor: Color = Color.black.opacity(0.6)
    var foregroundColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20)) // Use compact font size
            .frame(width: size, height: size) // Use compact size
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .clipShape(Circle())
            .shadow(radius: 3)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Pin Annotation View

struct PinAnnotationView: View {
    let pin: Pin
    @ObservedObject var viewModel: MapViewModel // Use ObservedObject if needed
    let onTap: () -> Void // Action to perform on tap
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: pin.incidentType.iconName)
                .font(.system(size: 20)) // Use compact font size
                .foregroundColor(.white)
                .padding(8)
                .background(pin.incidentType.color)
                .clipShape(Circle())
                .shadow(radius: 3)

            // Optional: Text label below pin
            // Text(pin.incidentType.rawValue)
            //    .font(.caption2)
            //    .foregroundColor(.black)
            //    .padding(2)
            //    .background(Color.white.opacity(0.7))
            //    .cornerRadius(4)
        }
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Preview

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock AuthState, potentially logged in
        let mockAuthState = AuthState()
        // mockAuthState.isUserAuthenticated = .signedIn // Or .signedOut, .undefined
        // You might need to set a mock user if MapView interacts with user data
        // mockAuthState.user = MockFirebaseUser(uid: "previewUID", email: "preview@example.com")

        MapView()
            .environmentObject(mockAuthState) // Provide mock auth state
            .environmentObject(NetworkMonitor()) // Provide mock network monitor
    }
} 
