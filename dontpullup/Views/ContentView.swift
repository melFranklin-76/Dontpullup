import SwiftUI
import MapKit

@available(iOS 16.0, *)  // Explicitly mark iOS 16 availability
struct ContentView: View {
    @StateObject private var mapViewModel = MapViewModel()
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    private let hapticImpact = UIImpactFeedbackGenerator(style: .medium)
    
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

struct OnboardingView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showingResources = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Title
                    VStack(spacing: 10) {
                        Text("DON'T PULL UP")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundColor(.red)
                        
                        Text("ON GRANDMA")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(-20))
                    }
                    
                    // Main Message
                    Text("Show us who they are so we can show them who we not")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 20) {
                        storySection(
                            title: "How It Works",
                            content: "• Long press to drop a pin\n• Choose the type of incident\n• Add a short video for verification\n• Pins are limited to 200 feet of your location\n• Only you can remove your own pins"
                        )
                        
                        storySection(
                            title: "Stay Safe",
                            content: "Remember: the best confrontation is the one you avoid. Use this information to stay away from potential trouble spots."
                        )
                        
                        // Resources Section
                        Button(action: {
                            showingResources = true
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Need Help?")
                                    .font(.title2.bold())
                                    .foregroundColor(.red)
                                
                                Text("Access our comprehensive list of anti-racism resources, legal support, and mental health services.")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding()
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showingResources) {
                NavigationView {
                    ResourcesView()
                }
            }
            .background(Color.black)
            .preferredColorScheme(.dark)
        }
    }
    
    private func storySection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2.bold())
                .foregroundColor(.red)
            
            Text(content)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// Remove the iOS 17 Preview macro and replace with traditional PreviewProvider
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
