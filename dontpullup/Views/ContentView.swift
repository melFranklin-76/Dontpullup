import SwiftUI
import MapKit

@available(iOS 16.0, *)  // Explicitly mark iOS 16 availability
/**
 The ContentView struct represents the main view of the application.
 It includes a map view, various UI elements, and handles user interactions.
 */
struct ContentView: View {
    @StateObject private var mapViewModel = MapViewModel()
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    private let hapticImpact = UIImpactFeedbackGenerator(style: .medium)
    
    /**
     The body property defines the view hierarchy for the ContentView.
     It includes a MapView, various UI elements, and handles user interactions.
     */
    var body: some View {
        ZStack {
            // Ensure MapView is the first layer
            MapView(viewModel: mapViewModel)
                .ignoresSafeArea()
                .preferredColorScheme(.dark)
                .onAppear {
                    // Request location when view appears
                    mapViewModel.centerOnUserLocation()
                }
            
            VStack {
                // Top Banner
                ZStack {
                    Text("DON'T PULL UP")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundColor(.red)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                    
                    Text("ON GRANDMA")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                        .shadow(color: .white.opacity(0.8), radius: 1, x: 0, y: 1)
                        .rotationEffect(.degrees(-20))
                        .offset(y: 5)
                }
                .padding(.top, 8)
                
                // Right side filters
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Spacer()
                        ForEach(IncidentType.allCases, id: \.self) { type in
                            filterButton(for: type)
                        }
                        Spacer()
                    }
                    .padding(.trailing)
                }
                
                Spacer()
                
                // Network status indicator
                if !networkMonitor.isConnected {
                    Text("Offline Mode - Some features may be limited")
                        .font(.caption)
                        .foregroundColor(.yellow)
                        .padding(.horizontal)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(5)
                }
                
                // Bottom controls
                HStack(spacing: 20) {
                    Button(action: {
                        hapticImpact.impactOccurred()
                        mapViewModel.showingHelp = true
                    }) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    // Center on user location button
                    Button(action: {
                        hapticImpact.impactOccurred()
                        mapViewModel.centerOnUserLocation()
                    }) {
                        Image(systemName: "location.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Edit mode toggle
                    Button(action: {
                        hapticImpact.impactOccurred()
                        mapViewModel.toggleEditMode()
                    }) {
                        Image(systemName: mapViewModel.isEditMode ? "xmark.circle.fill" : "pencil.circle.fill")
                            .font(.title)
                            .foregroundColor(mapViewModel.isEditMode ? .red : .white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        hapticImpact.impactOccurred()
                        mapViewModel.toggleMapType()
                    }) {
                        Image(systemName: mapViewModel.mapType == .standard ? "map.fill" : "map")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Sign out button
                    Button(action: {
                        mapViewModel.signOut()
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.75))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
            }
        }
        .sheet(isPresented: $mapViewModel.showingIncidentPicker) {
            IncidentTypePicker(viewModel: mapViewModel)
        }
        .sheet(isPresented: $mapViewModel.showingHelp) {
            HelpView()
        }
        .alert("Alert", isPresented: $mapViewModel.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(mapViewModel.alertMessage ?? "")
        }
    }
    
    /**
     Creates a filter button for the given incident type.
     
     - Parameter type: The incident type for which the filter button is created.
     - Returns: A view representing the filter button.
     */
    private func filterButton(for type: IncidentType) -> some View {
        Button(action: {
            hapticImpact.impactOccurred(intensity: 0.7)
            mapViewModel.toggleFilter(type)
        }) {
            Text(type.emoji)
                .font(.system(size: 30))
                .opacity(mapViewModel.selectedFilters.contains(type) ? 1.0 : 0.5)
                .padding(8)
                .background(
                    Circle()
                        .fill(mapViewModel.selectedFilters.contains(type) ? Color.red : Color.gray)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Remove the iOS 17 Preview macro and replace with traditional PreviewProvider
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
