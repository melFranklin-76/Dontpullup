import SwiftUI
import MapKit
import CoreLocationUI // For LocationButton

struct MainTabView: View {
    @StateObject private var mapViewModel = MapViewModel()
    @EnvironmentObject var authState: AuthState
    @Environment(\.colorScheme) var colorScheme
//    @Environment(\.horizontalSizeClass) private var horizontalSizeClass // REMOVED

    // State for managing sheets
    @State private var showingSettings = false
    @State private var showingProfile = false
    @State private var showingHelp = false

    // Video Player State (moved from MapView)
    @State private var showVideoPlayer = false
    @State private var videoPlayer: AVPlayer? = nil
    @State private var videoURLToPlay: URL? = nil
    @State private var isLoadingVideo = false

    // Incident Type Picker State (moved from MapView)
    @State private var showingIncidentPicker = false
    @State private var newPinCoordinate: CLLocationCoordinate2D?

    // Onboarding State
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentOnboardingStep = 0
    private let onboardingInstructions = [
        "Welcome to DontPullUp! Tap and hold on the map to drop a pin.",
        "Choose an incident type from the picker.",
        "Your pin appears on the map. Tap pins to view videos.",
        "Use the filters on the right to show specific incidents.",
        "Use the bottom buttons for Profile, Settings, etc.",
        "Upload progress shows in the center of screen. Pins update automatically."
    ]

    // Location Alert State
    @State private var showLocationDisabledAlert = false
    
    var body: some View {
        NavigationView { // Wrap content in NavigationView
        GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    // Map Layer
                    mapLayer(geometry: geometry)

                    // UI Overlays Layer
                    uiOverlays(geometry: geometry)

                    // Onboarding Layer
                    onboardingLayer(geometry: geometry)

                    // Loading/Progress Layer
                    loadingLayer(geometry: geometry)
                }
                .navigationBarHidden(true) // Hide the default navigation bar
            }
            .ignoresSafeArea(.keyboard) // Prevent keyboard from pushing UI up excessively
        }
        .navigationViewStyle(.stack) // Use stack style for consistency
        .sheet(isPresented: $showingSettings) { SettingsView().environmentObject(authState) }
        .sheet(isPresented: $showingProfile) { ProfileView().environmentObject(authState).environmentObject(AuthViewModel()) }
        .sheet(isPresented: $showingHelp) { HelpView() }
        .sheet(isPresented: $showVideoPlayer, onDismiss: stopVideo) { videoPlayerSheetContent() }
        .sheet(isPresented: $showingIncidentPicker) { incidentPickerSheetContent() }
        .alert("Location Disabled", isPresented: $showLocationDisabledAlert) { locationDisabledAlertButtons() } message: { locationDisabledAlertMessage() }
        .alert("Error", isPresented: $mapViewModel.showErrorAlert, error: mapViewModel.activeError) { errorAlertButtons() }
        .alert("Authentication Required", isPresented: $mapViewModel.showAuthenticationRequiredAlert) { authRequiredAlertButtons() } message: { authRequiredAlertMessage() }
        .alert("Too Far", isPresented: $mapViewModel.showDistanceAlert) { distanceAlertButtons() } message: { distanceAlertMessage() }
        .onChange(of: mapViewModel.locationManager.authorizationStatus, perform: handleAuthStatusChange)
        .onAppear(perform: handleOnAppear)
    }

    // MARK: - Layer Subviews

    @ViewBuilder
    private func mapLayer(geometry: GeometryProxy) -> some View {
        Map(coordinateRegion: $mapViewModel.region, showsUserLocation: true, annotationItems: mapViewModel.filteredPins) { pin in
            MapAnnotation(coordinate: pin.coordinate) {
                PinAnnotationView(pin: pin, viewModel: mapViewModel) {
                    Task { await playVideo(for: pin) }
                }
            }
        }
        .edgesIgnoringSafeArea(.top)
        .accentColor(Color(.systemPink))
        .onLongPressGesture(minimumDuration: 0.5) { screenCoordinate in
            handleLongPress(screenCoordinate: screenCoordinate, geometry: geometry)
        }
    }

    @ViewBuilder
    private func uiOverlays(geometry: GeometryProxy) -> some View {
        VStack {
            // Top Controls (Title/Logo + Filters)
            topControls(geometry: geometry)

            Spacer() // Pushes bottom controls down

            // Right Side Controls (Zoom + Location)
            rightSideControls(geometry: geometry)

            // Bottom Controls (Tabs/Buttons)
            bottomControls(geometry: geometry)
                                        }
                                    }

    @ViewBuilder
    private func onboardingLayer(geometry: GeometryProxy) -> some View {
        if !hasCompletedOnboarding && currentOnboardingStep < onboardingInstructions.count {
            Color.black.opacity(0.6)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { advanceOnboarding() }

            VStack {
                Spacer()
                Text(onboardingInstructions[currentOnboardingStep])
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                    .shadow(radius: 5)
                    .frame(maxWidth: geometry.size.width * 0.8)
                    .padding(.bottom, 80) // Position above bottom controls

                Text("Tap anywhere to continue (\(currentOnboardingStep + 1)/\(onboardingInstructions.count))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.bottom, 10)

                Button("Skip All") { skipOnboarding() }
                    .font(.footnote)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.6))
                    .cornerRadius(10)
                    .padding(.bottom, 40)

                Spacer()
                        }
            .transition(.opacity.animation(.easeInOut))
        }
    }

    @ViewBuilder
    private func loadingLayer(geometry: GeometryProxy) -> some View {
        // Loading Indicator for Video
        if isLoadingVideo {
            ProgressView("Loading Video...")
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .padding()
                .background(Color.black.opacity(0.6))
                .foregroundColor(.white)
                .cornerRadius(10)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                .zIndex(1)
                            }

        // Progress Indicator for Uploads
        if mapViewModel.isUploading {
             VStack {
                 Text("Uploading Video...")
                     .font(.caption)
                     .foregroundColor(.white)
                 ProgressView(value: mapViewModel.uploadProgress)
                     .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                     .padding(.horizontal, 6)
                     .frame(width: 150)
             }
             .padding(.vertical, 10)
             .padding(.horizontal, 12)
             .background(Color.black.opacity(0.7))
             .cornerRadius(8)
             .shadow(radius: 3)
             .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
             .transition(.opacity)
             .zIndex(1)
         }
    }

    // MARK: - Control Subviews

    @ViewBuilder
    private func topControls(geometry: GeometryProxy) -> some View {
         HStack {
             Text("DONTPULLUP")
                 .font(.custom("BlackOpsOne-Regular", size: 18)) // Use compact font size
                 .foregroundColor(colorScheme == .dark ? .white : .black)
                 .padding(.leading)

                        Spacer()
             // Add other top controls if needed (e.g., search bar)
         }
         .padding(.top, geometry.safeAreaInsets.top)
         .frame(height: 44) // Standard navigation bar height
    }


    @ViewBuilder
    private func rightSideControls(geometry: GeometryProxy) -> some View {
        VStack(alignment: .trailing) {
             Spacer() // Pushes controls down

             // Filter Buttons (Vertically)
             VStack(spacing: 12) { // Use compact spacing
                 ForEach(IncidentType.allCases.filter { $0 != .none }) { type in
                     filterButton(for: type, size: geometry.size)
                 }
             }
             .padding(.trailing, 16) // Use compact padding

             Spacer().frame(height: 30) // Space between filters and zoom/location

             // Zoom and Location Buttons
             VStack(spacing: 10) { // Use default spacing
                 Button { mapViewModel.zoomIn() } label: { Image(systemName: "plus") }
                     .buttonStyle(MapControlButton()) // Style applied

                 Button { mapViewModel.zoomOut() } label: { Image(systemName: "minus") }
                     .buttonStyle(MapControlButton())

                 LocationButton(.currentLocation) { mapViewModel.requestLocationUpdate() }
                                .foregroundColor(.white)
                     .cornerRadius(20) // Compact corner radius
                     .labelStyle(.iconOnly)
                     .symbolVariant(.fill)
                     .tint(colorScheme == .dark ? .gray.opacity(0.8) : .blue)
                     .frame(width: 40, height: 40) // Use compact size
                     .shadow(radius: 3)
             }
             .padding(.trailing, 16) // Use compact padding
             .padding(.bottom, geometry.safeAreaInsets.bottom + 70) // Adjust to position above bottom controls
         }
         .frame(maxWidth: .infinity, alignment: .trailing)
    }

    @ViewBuilder
    private func bottomControls(geometry: GeometryProxy) -> some View {
         let bottomControlSpacing: CGFloat = 20 // Use compact spacing
         let bottomControlSize: CGFloat = 40 // Use compact size

         HStack(spacing: bottomControlSpacing) {
                        Spacer()
             // Help Button
             Button { showingHelp = true } label: { Image(systemName: "questionmark.circle.fill") }
                 .buttonStyle(MapControlButton(size: bottomControlSize))

             // Settings Button
             Button { showingSettings = true } label: { Image(systemName: "gearshape.fill") }
                 .buttonStyle(MapControlButton(size: bottomControlSize))
                        
            // Map Type Button
            Button { mapViewModel.toggleMapType() } label: {
                 Image(systemName: mapViewModel.mapType == .standard ? "map.fill" : "globe.americas.fill")
             }
             .buttonStyle(MapControlButton(size: bottomControlSize))
                        
                        // Profile Button
             Button { showingProfile = true } label: { Image(systemName: "person.crop.circle.fill") }
                 .buttonStyle(MapControlButton(size: bottomControlSize))
             Spacer()
         }
         .padding(.horizontal, 12) // Use compact padding
         .padding(.bottom, geometry.safeAreaInsets.bottom + 4) // Use compact padding
         .frame(maxWidth: .infinity)
         .background(
             LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.5)]), startPoint: .top, endPoint: .bottom)
                 .edgesIgnoringSafeArea(.bottom)
                 .frame(height: geometry.safeAreaInsets.bottom + 60) // Adjust height
                 .offset(y: geometry.safeAreaInsets.bottom + 20) // Adjust offset
         )
    }

    // Helper for filter buttons
    @ViewBuilder
    private func filterButton(for type: IncidentType, size: CGSize) -> some View {
        let isSelected = mapViewModel.activeFilters.contains(type)
        let baseSize: CGFloat = 44 // Use compact size
        let baseFont: CGFloat = 20 // Use compact font size

        Button(action: { mapViewModel.toggleFilter(incidentType: type) }) {
            ZStack {
                Circle()
                     .fill(isSelected ? type.color : Color.gray.opacity(0.6))
                     .frame(width: baseSize, height: baseSize)
                     .shadow(radius: 2)

                 Image(systemName: type.iconName)
                     .font(.system(size: baseFont))
                     .foregroundColor(.white)
             }
             .overlay(
                 Circle()
                     .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
             )
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }

    // MARK: - Sheet Content

    @ViewBuilder
    private func videoPlayerSheetContent() -> some View {
        if let player = videoPlayer {
            VideoPlayer(player: player)
                .edgesIgnoringSafeArea(.all)
                .onAppear { player.play() }
        } else {
            VStack { Text("Could not load video."); ProgressView() }
                    }
                }

    @ViewBuilder
    private func incidentPickerSheetContent() -> some View {
        IncidentTypePicker(selectedType: $mapViewModel.selectedIncidentTypeForNewPin) {
            if let coordinate = newPinCoordinate, let type = mapViewModel.selectedIncidentTypeForNewPin {
                mapViewModel.uploadVideoAndCreatePin(coordinate: coordinate, incidentType: type)
                showingIncidentPicker = false
                newPinCoordinate = nil
            }
        }
    }

    // MARK: - Alert Content

    private func locationDisabledAlertButtons() -> some View {
        Group {
            Button("OK") { }
            Button("Settings") { openAppSettings() }
        }
    }

    private func locationDisabledAlertMessage() -> Text { Text("Location services are disabled. Please enable them in Settings to use map features.") }

    private func errorAlertButtons() -> some View { Button("OK") { mapViewModel.activeError = nil } }
    
    private func authRequiredAlertButtons() -> some View { Button("OK") { } }
    private func authRequiredAlertMessage() -> Text { Text("You need to be logged in to drop a pin.") }

    private func distanceAlertButtons() -> some View { Button("OK") { } }
    private func distanceAlertMessage() -> Text { Text("You must be within 200 feet of your current location to drop a pin.") }


    // MARK: - Event Handlers & Helpers

    private func handleOnAppear() {
        mapViewModel.checkIfLocationServicesIsEnabled()
    }

    private func handleAuthStatusChange(oldStatus: CLAuthorizationStatus, newStatus: CLAuthorizationStatus) {
        showLocationDisabledAlert = (newStatus == .denied || newStatus == .restricted)
    }

    private func handleLongPress(screenCoordinate: CGPoint, geometry: GeometryProxy) {
        guard authState.isUserAuthenticated == .signedIn && authState.currentUser != nil else {
            mapViewModel.showAuthenticationRequiredAlert = true
            return
        }
        let locationCoordinate = mapViewModel.convertScreenCoordinateToLocation(screenCoordinate: screenCoordinate, geometry: geometry)
        mapViewModel.checkDistanceAndPreparePin(coordinate: locationCoordinate) { isAllowed in
            if isAllowed {
                self.newPinCoordinate = locationCoordinate
                self.showingIncidentPicker = true
            }
        }
    }

    private func advanceOnboarding() {
        // HapticManager.feedback(.light)
        currentOnboardingStep += 1
        if currentOnboardingStep >= onboardingInstructions.count {
            hasCompletedOnboarding = true
            }
        }

    private func skipOnboarding() {
        // HapticManager.feedback(.medium)
        hasCompletedOnboarding = true
        currentOnboardingStep = onboardingInstructions.count // Ensure loop condition fails
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    private func playVideo(for pin: Pin) async {
         guard let videoURLString = pin.videoURL else {
             mapViewModel.activeError = PinError.missingURL; return
         }
         isLoadingVideo = true
         videoURLToPlay = await mapViewModel.fetchVideoURL(urlString: videoURLString)
         isLoadingVideo = false
         guard let url = videoURLToPlay else {
             mapViewModel.activeError = PinError.urlCreationFailed; return
         }
         videoPlayer = AVPlayer(url: url)
         showVideoPlayer = true
     }

    private func stopVideo() {
        videoPlayer?.pause()
        videoPlayer = nil
        videoURLToPlay = nil
        showVideoPlayer = false
    }
}

// MARK: - Previews
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AuthState.mockLoggedIn()) // Use mock state
            .environmentObject(NetworkMonitor()) // Provide network monitor
            // Add other necessary environment objects for preview
    }
} 
