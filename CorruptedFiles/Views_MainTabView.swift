import SwiftUI
import UIKit
import MapKit
import AVKit
import Combine

// Theme namespace for consistent colors
struct DPUTheme {
    struct colors {
        static let alertRed = Color(red: 0.9, green: 0.1, blue: 0.1)
    }
}

// MARK: - MainTabView
struct MainTabView: View {
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @EnvironmentObject private var authState: AuthState
    @StateObject private var mapViewModel = MapViewModel()
    
    var body: some View {
        MapContentView()
            .environmentObject(mapViewModel)
            .environmentObject(networkMonitor)
            .environmentObject(authState)
            .preferredColorScheme(.dark)
            // Global alerts & sheets
            .alert("Location Error", isPresented: $mapViewModel.showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(mapViewModel.alertMessage ?? "")
            }
            .sheet(isPresented: $mapViewModel.showingIncidentPicker) {
                IncidentTypePicker(viewModel: mapViewModel)
            }
            .sheet(isPresented: $mapViewModel.showingHelp) {
                HelpView()
            }
            .sheet(isPresented: $mapViewModel.showingSettings) {
                SettingsView()
            }
    }
}

// MARK: - MapContentView
private struct MapContentView: View {
    @EnvironmentObject private var mapViewModel: MapViewModel
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @EnvironmentObject private var authState: AuthState

    // Local presentation states
    @State private var showingProfile = false
    @State private var showingTermsOfService = false
    @State private var showingPrivacyPolicy = false

    // UI helpers
    private let hapticImpact = UIImpactFeedbackGenerator(style: .medium)

    // Marquee state
    @State private var marqueeOffset: CGFloat = 0
    @State private var shouldAnimateMarquee = false
    private let marqueeSpacer = "  " // Double space at the end
    private let baseMarqueeText = "SHOW US WHO THEY ARE        WE WILL SHOW THEM WHO WE ARE NOT"
    private var marqueeText: String { baseMarqueeText + marqueeSpacer }

    // Notification publishers
    private let termsOfServicePublisher = NotificationCenter.default.publisher(for: Notification.Name("OpenTermsOfService"))
    private let privacyPolicyPublisher = NotificationCenter.default.publisher(for: Notification.Name("OpenPrivacyPolicy"))

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background map
                MapView(viewModel: mapViewModel)
                    .edgesIgnoringSafeArea(.all)
                    .preferredColorScheme(.dark)
                    .onAppear {
                        mapViewModel.centerOnUserLocation()
                    }

                VStack(spacing: 0) {
                    topBanner(in: geometry)

                    Spacer()

                    rightIndicators
                        .padding(.trailing, 16)

                    Spacer()

                    if !networkMonitor.isConnected {
                        offlineBanner
                    }

                    bottomToolbar(geometry: geometry)
                }
            }
        }
        // MARK: – Sheet presenters
        .onReceive(termsOfServicePublisher) { _ in showingTermsOfService = true }
        .onReceive(privacyPolicyPublisher) { _ in showingPrivacyPolicy = true }
        .sheet(isPresented: $showingProfile) { ProfileView() }
        .sheet(isPresented: $showingTermsOfService) {
            NavigationView {
                TermsOfServiceView()
                    .navigationBarItems(trailing: Button("Done") { showingTermsOfService = false })
            }.preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            NavigationView {
                PrivacyPolicyView()
                    .navigationBarItems(trailing: Button("Done") { showingPrivacyPolicy = false })
            }.preferredColorScheme(.dark)
        }
    }

    // MARK: – Sub-views

    private func topBanner(in geometry: GeometryProxy) -> some View {
        ZStack {
            // Background title
            Text("DON'T PULL UP")
                .font(.system(size: min(25, geometry.size.width * 0.06), weight: .heavy))
                .foregroundColor(.yellow)
                .tracking(2.0)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, geometry.size.width * 0.1)

            // Marquee text
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    Text(marqueeText)
                    Text(marqueeText)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.black)
                .tracking(1.5)
                .fixedSize()
                .offset(x: marqueeOffset)
            }
            .disabled(true)
            .frame(maxWidth: .infinity)
            .clipped()
            .shadow(color: .black.opacity(0.5), radius: 1)
            .offset(y: 5)
            .onAppear {
                let font = UIFont.systemFont(ofSize: 12, weight: .medium)
                let textWidth = marqueeText.widthOfString(usingFont: font) + (CGFloat(marqueeText.count) * 1.5)
                marqueeOffset = 0
                shouldAnimateMarquee = true
                withAnimation(.linear(duration: Double(textWidth / 37.5)).repeatForever(autoreverses: false)) {
                    marqueeOffset = -textWidth
                }
            }
            .id(shouldAnimateMarquee)

            // Sub-title
            VStack {
                Spacer().frame(height: 20)
                Text("ON GRANDMA!")
                    .font(.custom("BlackOpsOne-Regular", size: min(18, geometry.size.width * 0.045)))
                    .foregroundColor(DPUTheme.colors.alertRed)
                    .tracking(1.0)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    .rotationEffect(.degrees(-15))
            }
        }
        .padding(.top, geometry.safeAreaInsets.top - 35)
    }

    private var rightIndicators: some View {
        HStack {
            Spacer()
            VStack(spacing: 20) {
                indicatorButton(emoji: "📢", filter: .verbal)
                indicatorButton(emoji: "👊", filter: .physical)
                indicatorButton(emoji: "🚨", filter: .emergency)
                indicatorButton(emoji: "📱") {
                    mapViewModel.toggleMyPinsFilter()
                } isSelected: { mapViewModel.showingOnlyMyPins }

                Spacer()

                zoomButton(systemName: "plus", action: mapViewModel.zoomIn)
                zoomButton(systemName: "minus", action: mapViewModel.zoomOut)
            }
        }
    }

    private func bottomToolbar(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            toolbarButton(systemName: "questionmark.circle") {
                mapViewModel.showingHelp = true
            }

            toolbarButton(systemName: "gear") {
                mapViewModel.showingSettings = true
            }

            toolbarButton(systemName: "location") {
                mapViewModel.centerOnUserLocation()
            }

            toolbarButton(systemName: mapViewModel.mapType == .standard ? "map.fill" : "globe.americas.fill") {
                mapViewModel.toggleMapType()
            }

            toolbarButton(systemName: mapViewModel.isEditMode ? "xmark.circle" : "pencil", tint: mapViewModel.isEditMode ? .red : .white) {
                mapViewModel.toggleEditMode()
            }

            toolbarButton(systemName: "rectangle.portrait.and.arrow.right") {
                authState.signOut()
            }
        }
        .padding(.bottom, geometry.safeAreaInsets.bottom)
    }

    // MARK: – UI Helpers

    private func indicatorButton(emoji: String, filter: IncidentType? = nil, action: (() -> Void)? = nil, isSelected: (() -> Bool)? = nil) -> some View {
        Button {
            hapticImpact.impactOccurred()
            if let filter = filter {
                mapViewModel.toggleFilter(filter)
            } else {
                action?()
            }
        } label: {
            ZStack {
                Circle()
                    .fill((isSelected?() ?? mapViewModel.selectedFilters.contains(filter ?? .verbal)) ? Color.red.opacity(0.7) : Color.black.opacity(0.6))
                    .frame(width: 50, height: 50)
                Text(emoji).font(.system(size: 24))
            }
        }
    }

    private func zoomButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button {
            hapticImpact.impactOccurred()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
        }
    }

    private func toolbarButton(systemName: String, tint: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: {
            hapticImpact.impactOccurred()
            action()
        }) {
            Image(systemName: systemName)
                .font(.system(size: 22))
                .foregroundColor(tint)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
    }

    private var offlineBanner: some View {
        Text("Offline Mode - Some features may be limited")
            .font(.caption2)
            .foregroundColor(.yellow)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.7))
            .cornerRadius(4)
            .padding(.bottom, 4)
    }
}

// MARK: - String width helper
private extension String {
    func widthOfString(usingFont font: UIFont) -> CGFloat {
        let attributes = [NSAttributedString.Key.font: font]
        return size(withAttributes: attributes).width
    }
}

// MARK: - Preview
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(NetworkMonitor())
            .environmentObject(AuthState())
    }
} 