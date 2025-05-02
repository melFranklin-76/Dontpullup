import SwiftUI
import UIKit
import MapKit
import AVKit
import Combine

struct MainTabView: View {
    @EnvironmentObject private var authState: AuthState
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @StateObject private var mapViewModel = MapViewModel()
    @StateObject private var onboardingManager = OnboardingManager.shared
    
    var body: some View {
        // Directly show MapContentView without TabView wrapper
        MapContentView()
            .environmentObject(mapViewModel)
            .environmentObject(authState)
            .environmentObject(networkMonitor)
            .environmentObject(onboardingManager)
            .preferredColorScheme(.dark)
            .onAppear {
                // Start onboarding when app appears
                onboardingManager.startOnboarding()
            }
    }
}

struct MapContentView: View {
    @EnvironmentObject private var mapViewModel: MapViewModel
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @EnvironmentObject private var authState: AuthState
    @EnvironmentObject private var onboardingManager: OnboardingManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
                    MapView()
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
                                // Use adaptive spacing based on size class
                                let zoomButtonSpacing: CGFloat = horizontalSizeClass == .regular ? 15 : 10
                                let zoomButtonSize: CGFloat = horizontalSizeClass == .regular ? 50 : 40
                                VStack(spacing: zoomButtonSpacing) { // Adaptive spacing
                                    Button(action: { mapViewModel.zoomIn() }) {
                                        Image(systemName: "plus.magnifyingglass")
                                            .font(.system(size: horizontalSizeClass == .regular ? 24 : 20)) // Slightly larger icon on iPad
                                            .foregroundColor(.white)
                                            .frame(width: zoomButtonSize, height: zoomButtonSize) // Adaptive size
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Circle())
                                    }
                                    Button(action: { mapViewModel.zoomOut() }) {
                                        Image(systemName: "minus.magnifyingglass")
                                            .font(.system(size: horizontalSizeClass == .regular ? 24 : 20)) // Slightly larger icon on iPad
                                            .foregroundColor(.white)
                                            .frame(width: zoomButtonSize, height: zoomButtonSize) // Adaptive size
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Circle())
                                    }
                                }
                                .padding(.trailing, horizontalSizeClass == .regular ? 24 : 16) // Adaptive padding
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
                            // Use adaptive font style based on size class
                            .font(horizontalSizeClass == .regular ? .title2.weight(.heavy) : .title3.weight(.heavy))
                            .foregroundColor(.yellow)
                            .tracking(2.0)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, geometry.size.width * 0.1) // Keep horizontal padding geometry-based for now

                        // Marquee sits visually above "ON GRANDMA!" within the ZStack
                        // Use alignmentGuide or offset for precise vertical centering if needed
                        GeometryReader { marqueeGeometry in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 0) {
                                    Text(marqueeText)
                                        // Use standard style supporting Dynamic Type
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.black)
                                        .tracking(1.5)
                                        .fixedSize(horizontal: true, vertical: false)
                                    Text(marqueeText)
                                        // Use standard style supporting Dynamic Type
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.black)
                                        .tracking(1.5)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                .offset(x: marqueeOffset)
                                .onAppear {
                                    // Calculate width based on the first Text element
                                    let actualTextWidth = marqueeGeometry.size.width / 2 // Since we have two identical texts
                                    let duration = Double(actualTextWidth) / 30.0 // Adjust divisor for speed

                                    // Reset offset before starting animation
                                    marqueeOffset = 0
                                    // Add a slight delay to ensure layout is complete before animating
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                                            marqueeOffset = -actualTextWidth // Scroll by the exact width of one text block
                                        }
                                    }
                                }
                            }
                            .disabled(true) // Keep scroll disabled
                        }
                        .frame(height: 20) // Give GeometryReader a defined height for the banner
                        .clipped() // Clip content outside the GeometryReader frame
                        .shadow(color: .black.opacity(0.5), radius: 1)
                        // Offset slightly below the vertical center for positioning between banners
                        .offset(y: 5) // Adjust this offset value as needed

                        // ON GRANDMA! Text
                        VStack(spacing: 0) {
                            Spacer() // Pushes ON GRANDMA down within its ZStack layer
                                .frame(height: 20) // Adjust as needed based on desired banner spacing

                            Text("ON GRANDMA!")
                                // Use adaptive size with custom font
                                .font(.custom("BlackOpsOne-Regular", size: horizontalSizeClass == .regular ? 24 : 18))
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
                        // Use adaptive spacing based on size class
                        let filterButtonSpacing: CGFloat = horizontalSizeClass == .regular ? 18 : 12
                        VStack(spacing: filterButtonSpacing) { // Adaptive spacing
                            ForEach(IncidentType.allCases, id: \.self) { type in
                                // Pass horizontalSizeClass to filterButton
                                filterButton(for: type, size: geometry.size, horizontalSizeClass: horizontalSizeClass)
                            }
                            
                            // Device-specific pins filter button
                            Button(action: {
                                hapticImpact.impactOccurred()
                                mapViewModel.toggleMyPinsFilter()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(mapViewModel.showingOnlyMyPins ? Color.blue : Color.gray.opacity(0.5))
                                        // Use adaptive size - ensure minimum 44x44
                                        .frame(width: horizontalSizeClass == .regular ? 48 : 44, height: horizontalSizeClass == .regular ? 48 : 44)
                                    
                                    Text("📱")
                                        .font(.system(size: horizontalSizeClass == .regular ? 24 : 20)) // Adaptive emoji size
                                }
                            }
                        }
                        .padding(.trailing, horizontalSizeClass == .regular ? 24 : 16) // Adaptive padding
                        .tag(101) // Tag for onboarding tooltip
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
                    // Use adaptive spacing based on size class
                    let bottomControlSpacing: CGFloat = horizontalSizeClass == .regular ? 30 : 20
                    let bottomControlSize: CGFloat = horizontalSizeClass == .regular ? 50 : 40
                    HStack(spacing: bottomControlSpacing) { // Adaptive spacing
                        Button(action: {
                            hapticImpact.impactOccurred()
                            mapViewModel.showingHelp = true
                        }) {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.system(size: horizontalSizeClass == .regular ? 28 : 24)) // Adaptive icon size
                                .foregroundColor(.white)
                                .frame(width: bottomControlSize, height: bottomControlSize) // Adaptive size
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        
                        // Settings Button
                        Button(action: {
                            hapticImpact.impactOccurred()
                            showingSettings = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: horizontalSizeClass == .regular ? 28 : 24)) // Adaptive icon size
                                .foregroundColor(.white)
                                .frame(width: bottomControlSize, height: bottomControlSize) // Adaptive size
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
                                .font(.system(size: horizontalSizeClass == .regular ? 28 : 24)) // Adaptive icon size
                                .foregroundColor(.white)
                                .frame(width: bottomControlSize, height: bottomControlSize) // Adaptive size
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        .tag(100) // Tag for onboarding tooltip
                        
                        // Edit Mode Button (Restored)
                        Button(action: {
                            hapticImpact.impactOccurred()
                            mapViewModel.toggleEditMode()
                        }) {
                            Image(systemName: mapViewModel.isEditMode ? "xmark.circle.fill" : "pencil.circle.fill")
                                .font(.system(size: horizontalSizeClass == .regular ? 28 : 24)) // Adaptive icon size
                                .foregroundColor(mapViewModel.isEditMode ? .red : .white)
                                .frame(width: bottomControlSize, height: bottomControlSize) // Adaptive size
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        
                        // Map Type Button (Restored)
                        Button(action: {
                            hapticImpact.impactOccurred()
                            mapViewModel.toggleMapType()
                        }) {
                            Image(systemName: mapViewModel.mapType == .standard ? "map.fill" : "map")
                                .font(.system(size: horizontalSizeClass == .regular ? 28 : 24)) // Adaptive icon size
                                .foregroundColor(.white)
                                .frame(width: bottomControlSize, height: bottomControlSize) // Adaptive size
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }

                        // Profile Button
                        Button(action: {
                            hapticImpact.impactOccurred()
                            showingProfile = true
                        }) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: horizontalSizeClass == .regular ? 28 : 24)) // Adaptive icon size
                                .foregroundColor(.white)
                                .frame(width: bottomControlSize, height: bottomControlSize) // Adaptive size
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        .tag(102) // Tag for onboarding tooltip
                    }
                    .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 12) // Adaptive padding
                    .padding(.bottom, horizontalSizeClass == .regular ? 10 : 4) // Adaptive padding
                }
            }
            // Apply onboarding tooltips to the entire view
            .withOnboardingTooltips()
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
                .onAppear {
                    if isPad() {
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = windowScene.windows.first,
                           let rootVC = window.rootViewController,
                           let presentedVC = rootVC.presentedViewController {
                            
                            presentedVC.modalPresentationStyle = .fullScreen
                            presentedVC.modalTransitionStyle = .crossDissolve
                        }
                    }
                }
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
    
    private func filterButton(for type: IncidentType, size: CGSize, horizontalSizeClass: UserInterfaceSizeClass?) -> some View {
        Button(action: {
            hapticImpact.impactOccurred()
            mapViewModel.toggleFilter(type)
        }) {
            ZStack {
                Circle()
                    .fill(mapViewModel.selectedFilters.contains(type) ? type.color : Color.gray.opacity(0.5))
                    // Use adaptive size - ensure minimum 44x44
                    .frame(width: horizontalSizeClass == .regular ? 48 : 44, height: horizontalSizeClass == .regular ? 48 : 44)
                
                Text(type.emoji)
                    // Use adaptive emoji size
                    .font(.system(size: horizontalSizeClass == .regular ? 24 : 20))
            }
        }
    }
}

// Simple helper to detect iPads reliably
private func isPad() -> Bool {
    return UIDevice.current.userInterfaceIdiom == .pad
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