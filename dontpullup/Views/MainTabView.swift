import SwiftUI
import UIKit
import MapKit
import AVKit
import Combine

struct MainTabView: View {
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @StateObject private var mapViewModel = MapViewModel()
    
    var body: some View {
        MapContentView()
            .environmentObject(mapViewModel)
            .environmentObject(networkMonitor)
            .preferredColorScheme(.dark)
            .alert("Location Error", isPresented: $mapViewModel.showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(mapViewModel.alertMessage)
            }
            .sheet(isPresented: $mapViewModel.showingIncidentPicker) {
                IncidentTypePicker(viewModel: mapViewModel)
            }
            .sheet(isPresented: $mapViewModel.showingHelp) {
                HelpView()
            }
    }
}

struct MapContentView: View {
    @EnvironmentObject private var mapViewModel: MapViewModel
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @State private var showingSettings = false
    @State private var showingProfile = false
    @State private var showingTermsOfService = false
    @State private var showingPrivacyPolicy = false
    private let hapticImpact = UIImpactFeedbackGenerator(style: .medium)
    
    // State for marquee animation
    @State private var marqueeOffset: CGFloat = 0
    @State private var shouldAnimateMarquee = false
    private let marqueeSpacer = "  "  // Double space at the end
    private let baseMarqueeText = "SHOW US WHO THEY ARE        WE WILL SHOW THEM WHO WE ARE NOT"  
    private var marqueeText: String { baseMarqueeText + marqueeSpacer }
    
    // Create publishers for the notification events
    private let termsOfServicePublisher = NotificationCenter.default
        .publisher(for: Notification.Name("OpenTermsOfService"))
    
    private let privacyPolicyPublisher = NotificationCenter.default
        .publisher(for: Notification.Name("OpenPrivacyPolicy"))
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // MapView should be the background with nothing behind it
                MapView(viewModel: mapViewModel)
                    .edgesIgnoringSafeArea(.all)
                    .preferredColorScheme(.dark)
                    .onAppear {
                        // Debug alert for location permissions and map visibility
                        print("DEBUG: MainTabView appeared - Adding debug info")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            // Instead of directly checking CLLocationManager, use the MapViewModel
                            // which already has a properly configured location manager delegate
                            print("DEBUG: Location authorized: \(mapViewModel.isLocationAuthorized)")
                            // Don't call CLLocationManager.locationServicesEnabled() directly
                            // This can cause UI unresponsiveness
                            print("DEBUG: Location services status being monitored by MapViewModel")
                        }
                    
                        // Trigger centralized permission flow
                        mapViewModel.checkAndRequestLocationPermission()
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
                                .font(.custom("BlackOpsOne-Regular", size: min(18, geometry.size.width * 0.045)))
                                .foregroundColor(DPUTheme.colors.alertRed)
                                .tracking(1.0)
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                .rotationEffect(.degrees(-15))
                        }
                    }
                    // Position banner directly under the dynamic island
                    .padding(.top, geometry.safeAreaInsets.top - 35) // Significant negative adjustment to position right under dynamic island

                    Spacer() // Pushes filters/bottom controls down
                    
                    // Right side indicators
                    HStack {
                        Spacer()
                        VStack(spacing: 20) {
                            // Indicator buttons
                            indicatorButton(emoji: "📢", action: {
                                hapticImpact.impactOccurred()
                                mapViewModel.toggleFilter(.verbal)
                            }, isSelected: mapViewModel.selectedFilters.contains(.verbal))
                            
                            indicatorButton(emoji: "👊", action: {
                                hapticImpact.impactOccurred()
                                mapViewModel.toggleFilter(.physical)
                            }, isSelected: mapViewModel.selectedFilters.contains(.physical))
                            
                            indicatorButton(emoji: "🚨", action: {
                                hapticImpact.impactOccurred()
                                mapViewModel.toggleFilter(.emergency)
                            }, isSelected: mapViewModel.selectedFilters.contains(.emergency))
                            
                            indicatorButton(emoji: "📱", action: {
                                hapticImpact.impactOccurred()
                                mapViewModel.toggleMyPinsFilter()
                            }, isSelected: mapViewModel.showingOnlyMyPins)
                            
                            Spacer()
                            
                            // Zoom controls
                            Button(action: {
                                hapticImpact.impactOccurred()
                                mapViewModel.zoomIn()
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            
                            Button(action: {
                                hapticImpact.impactOccurred()
                                mapViewModel.zoomOut()
                            }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.trailing, 16)
                    }
                    
                    Spacer()
                    
                    // Network status indicator (if needed)
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
                    
                    // Bottom toolbar
                    HStack(spacing: 0) {
                        // Help button
                        toolbarButton(systemName: "questionmark.circle", action: {
                            hapticImpact.impactOccurred()
                            mapViewModel.showingHelp = true
                        })
                        
                        // Settings button
                        toolbarButton(systemName: "gear", action: {
                            hapticImpact.impactOccurred()
                            showingSettings = true
                        })
                        
                        // Center on location button
                        toolbarButton(systemName: "location", action: {
                            hapticImpact.impactOccurred()
                            mapViewModel.centerOnUserLocation()
                        })
                        
                        // NEW: Map type toggle button
                        toolbarButton(systemName: mapViewModel.mapType == .standard ? "map.fill" : "globe.americas.fill", action: {
                            hapticImpact.impactOccurred()
                            mapViewModel.toggleMapType()
                        })
                        
                        // Edit mode toggle button
                        toolbarButton(
                            systemName: mapViewModel.isEditMode ? "xmark.circle" : "pencil",
                            action: {
                                hapticImpact.impactOccurred()
                                mapViewModel.toggleEditMode()
                            },
                            tint: mapViewModel.isEditMode ? .red : .white
                        )
                        
                        // Profile button
                        toolbarButton(systemName: "person.circle", action: {
                            hapticImpact.impactOccurred()
                            showingProfile = true
                        })
                    }
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
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
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView()
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
    }
    
    // Helper function for indicator buttons (right side)
    private func indicatorButton(emoji: String, action: @escaping () -> Void, isSelected: Bool) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.red.opacity(0.7) : Color.black.opacity(0.6))
                    .frame(width: 50, height: 50)
                
                Text(emoji)
                    .font(.system(size: 24))
            }
        }
    }
    
    // Helper function for toolbar buttons (bottom)
    private func toolbarButton(systemName: String, action: @escaping () -> Void, tint: Color = .white) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22))
                .foregroundColor(tint)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
    }
    
    // Legacy filter button function - keeping for reference but not using
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