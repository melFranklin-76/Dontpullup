import SwiftUI
import UIKit
import MapKit
import AVKit
import Combine

struct MainTabView: View {
    @EnvironmentObject private var authState: AuthState
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @StateObject private var mapViewModel = MapViewModel()
    
    var body: some View {
        // Directly show MapContentView without TabView wrapper
        MapContentView()
            .environmentObject(mapViewModel)
            .environmentObject(authState)
            .environmentObject(networkMonitor)
            .preferredColorScheme(.dark)
    }
}

struct MapContentView: View {
    @EnvironmentObject private var mapViewModel: MapViewModel
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @EnvironmentObject private var authState: AuthState
    @State private var showingSettings = false
    @State private var showingProfile = false
    @State private var showingTermsOfService = false
    @State private var showingPrivacyPolicy = false
    private let hapticImpact = UIImpactFeedbackGenerator(style: .medium)
    
    // State for marquee animation
    @State private var marqueeOffset: CGFloat = 0
    @State private var shouldAnimateMarquee = false
    // Define phrases and pause spacing for marquee
    private let phrase1 = "SHOW US WHO THEY ARE"
    private let phrase2 = "SO WE CAN SHOW THEM WHO WE ARE NOT"
    private let pauseSpacing = String(repeating: " ", count: 50) // Adjust space count for pause duration
    private var baseMarqueeText: String { phrase1 + pauseSpacing + phrase2 }
    // Use pauseSpacing also at the end for a pause before looping
    private var marqueeText: String { baseMarqueeText + pauseSpacing }
    
    // Create publishers for the notification events
    private let termsOfServicePublisher = NotificationCenter.default
        .publisher(for: Notification.Name("OpenTermsOfService"))
    
    private let privacyPolicyPublisher = NotificationCenter.default
        .publisher(for: Notification.Name("OpenPrivacyPolicy"))
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Wrap MapView in ZStack
                ZStack {
                    MapView(viewModel: mapViewModel)
                        .edgesIgnoringSafeArea(.all)
                        .preferredColorScheme(.dark)
                        .onAppear {
                            mapViewModel.centerOnUserLocation()
                        }
                    
                    // Add Zoom Buttons Overlay
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(spacing: 10) {
                                Button(action: { mapViewModel.zoomIn() }) {
                                    Image(systemName: "plus.magnifyingglass")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                        .frame(width: 40, height: 40)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                Button(action: { mapViewModel.zoomOut() }) {
                                    Image(systemName: "minus.magnifyingglass")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                        .frame(width: 40, height: 40)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.trailing, 16)
                            // Align with filter buttons slightly
                            .padding(.bottom, geometry.safeAreaInsets.bottom + 60) // Adjust vertical position relative to bottom controls
                        }
                    }
                }
                
                VStack(spacing: 0) {
                    // Top Banner Area - Reduced overall top padding
                    ZStack {
                        // Background "DON'T PULL UP" text
                        Text("DON'T PULL UP")
                            .font(.system(size: min(25, geometry.size.width * 0.06), weight: .heavy))
                            .foregroundColor(.yellow)
                            .tracking(2.0)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, geometry.size.width * 0.1)

                        // Marquee sits visually above "ON GRANDMA!" within the ZStack
                        // Use alignmentGuide or offset for precise vertical centering if needed
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 0) {
                                Text(marqueeText)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.black)
                                    .tracking(1.5)
                                    .fixedSize(horizontal: true, vertical: false)
                                Text(marqueeText)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.black)
                                    .tracking(1.5)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .offset(x: marqueeOffset)
                        }
                        .disabled(true)
                        .frame(maxWidth: .infinity) // Takes width for clipping
                        .clipped()
                        .shadow(color: .black.opacity(0.5), radius: 1)
                        // Offset slightly below the vertical center for positioning between banners
                        .offset(y: 5) // Adjust this offset value as needed
                        .onAppear {
                            let font = UIFont.systemFont(ofSize: 12, weight: .medium)
                            let textWidth = marqueeText.widthOfString(usingFont: font) + (CGFloat(marqueeText.count) * 1.5)
                            marqueeOffset = 0
                            shouldAnimateMarquee = true
                            // Significantly slower animation - reduced speed by another 50% (now 25% of original)
                            withAnimation(.linear(duration: Double(textWidth / 37.5)).repeatForever(autoreverses: false)) {
                                marqueeOffset = -textWidth
                            }
                        }
                        .id(shouldAnimateMarquee)

                        // ON GRANDMA! Text
                        VStack(spacing: 0) {
                            Spacer() // Pushes ON GRANDMA down within its ZStack layer
                                .frame(height: 20) // Adjust as needed based on desired banner spacing

                            Text("ON GRANDMA!")
                                .font(.custom("BlackOpsOne-Regular", size: min(22.5, geometry.size.width * 0.05625)))
                                .foregroundColor(DPUTheme.colors.alertRed)
                                .tracking(1.0)
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                .rotationEffect(.degrees(-15))
                        }
                    }
                    // Position banner directly under the dynamic island
                    .padding(.top, geometry.safeAreaInsets.top - 35) // Significant negative adjustment to position right under dynamic island

                    Spacer() // Pushes filters/bottom controls down
                    
                    // Right side filters
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            ForEach(IncidentType.allCases, id: \.self) { type in
                                filterButton(for: type, size: geometry.size)
                            }
                            
                            // Device-specific pins filter button
                            Button(action: {
                                hapticImpact.impactOccurred()
                                mapViewModel.toggleMyPinsFilter()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(mapViewModel.showingOnlyMyPins ? Color.blue : Color.gray.opacity(0.5))
                                        .frame(width: 35, height: 35)
                                    
                                    Text("📱")
                                        .font(.system(size: 20))
                                }
                            }
                        }
                        .padding(.trailing, 16)
                    }
                    
                    Spacer()
                    
                    // Network status indicator
                    if !networkMonitor.isConnected {
                        Text("Offline Mode - Some features may be limited")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                            .padding(.bottom, 4)
                    }
                    
                    // Bottom controls
                    HStack(spacing: 20) {
                        Button(action: {
                            hapticImpact.impactOccurred()
                            mapViewModel.showingHelp = true
                        }) {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        
                        // Settings Button
                        Button(action: {
                            hapticImpact.impactOccurred()
                            showingSettings = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }

                        Spacer()
                        
                        // Center Location Button
                        Button(action: {
                            hapticImpact.impactOccurred()
                            mapViewModel.centerOnUserLocation()
                        }) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        
                        // Edit Mode Button (Restored)
                        Button(action: {
                            hapticImpact.impactOccurred()
                            mapViewModel.toggleEditMode()
                        }) {
                            Image(systemName: mapViewModel.isEditMode ? "xmark.circle.fill" : "pencil.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(mapViewModel.isEditMode ? .red : .white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        
                        // Map Type Button (Restored)
                        Button(action: {
                            hapticImpact.impactOccurred()
                            mapViewModel.toggleMapType()
                        }) {
                            Image(systemName: mapViewModel.mapType == .standard ? "map.fill" : "map")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }

                        // Profile Button
                        Button(action: {
                            hapticImpact.impactOccurred()
                            showingProfile = true
                        }) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                }
            }
        }
        // Listen for notification events using onReceive
        .onReceive(termsOfServicePublisher) { _ in
            showingTermsOfService = true
        }
        .onReceive(privacyPolicyPublisher) { _ in
            showingPrivacyPolicy = true
        }
        .sheet(isPresented: $mapViewModel.showingIncidentPicker) {
            IncidentTypePicker(viewModel: mapViewModel)
        }
        .fullScreenOrSheet(isPresented: $mapViewModel.showingHelp) {
            HelpView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(authState)
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView()
                .environmentObject(authState)
        }
        .sheet(isPresented: $showingTermsOfService) {
            // Present the dedicated TermsOfServiceView
            NavigationView {
                TermsOfServiceView()
                    .navigationBarItems(trailing: Button("Done") { showingTermsOfService = false })
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            // Present the dedicated PrivacyPolicyView
            NavigationView {
                PrivacyPolicyView()
                    .navigationBarItems(trailing: Button("Done") { showingPrivacyPolicy = false })
            }
            .preferredColorScheme(.dark)
        }
        .alert("Alert", isPresented: $mapViewModel.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(mapViewModel.alertMessage ?? "")
        }
    }
    
    private func filterButton(for type: IncidentType, size: CGSize) -> some View {
        Button(action: {
            hapticImpact.impactOccurred()
            mapViewModel.toggleFilter(type)
        }) {
            ZStack {
                Circle()
                    .fill(mapViewModel.selectedFilters.contains(type) ? type.color : Color.gray.opacity(0.5))
                    .frame(width: 35, height: 35)
                
                Text(type.emoji)
                    .font(.system(size: 20))
            }
        }
    }
}

// Helper extension to estimate text width (simplistic)
extension String {
    func widthOfString(usingFont font: UIFont) -> CGFloat {
        let fontAttributes = [NSAttributedString.Key.font: font]
        let size = self.size(withAttributes: fontAttributes)
        return size.width
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AuthState.shared)
            .environmentObject(NetworkMonitor())
    }
}

#if DEBUG
// ... existing code ...
#endif

// MARK: - Full Screen or Sheet Helper
extension View {
    /// Presents HelpView as a full screen cover on iOS14+ and fallback to sheet on earlier versions, with full screen coverage.
    @ViewBuilder
    func fullScreenOrSheet<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        if #available(iOS 14.0, *) {
            fullScreenCover(isPresented: isPresented) {
                content()
                    .edgesIgnoringSafeArea(.all)
            }
        } else {
            // For iOS 13, use sheet but force max height
            sheet(isPresented: isPresented) {
                content()
                    .frame(maxHeight: .infinity) // Encourage full height
                    .edgesIgnoringSafeArea(.all) // Still ignore safe area within sheet
            }
        }
    }
} 