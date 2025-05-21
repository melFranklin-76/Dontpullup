import SwiftUI
import Firebase
import MessageUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject private var authState: AuthState
    @Environment(\.dismiss) private var dismiss
    @State private var notificationsEnabled = true
    @State private var locationTrackingEnabled = true
    @State private var darkModeEnabled = true
    @State private var hapticFeedbackEnabled = true
    @State private var showResetConfirmation = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    @State private var showMailComposer = false
    @State private var showAbout = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Image("welcome_background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
                
                Color.black.opacity(0.7)
                    .edgesIgnoringSafeArea(.all)
                    
                VStack {
                    // Add spacing at the top to prevent crowding with status bar
                    Spacer()
                        .frame(height: 16)
                        
                    Form {
                        // Improve section header visibility and spacing
                        Section(header: 
                            Text("GENERAL")
                                .foregroundColor(.white)
                                .font(.headline)
                                .padding(.top, 16)
                                .padding(.bottom, 8)
                        ) {
                            // Add more spacing between toggle items
                            Toggle("Enable Notifications", isOn: $notificationsEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .red))
                                .padding(.vertical, 8)
                            
                            Toggle("Location Tracking", isOn: $locationTrackingEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .red))
                                .padding(.vertical, 8)
                            
                            Toggle("Dark Mode", isOn: $darkModeEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .red))
                                .disabled(true) // Disabled as app is dark mode only
                                .padding(.vertical, 8)
                            
                            Toggle("Haptic Feedback", isOn: $hapticFeedbackEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .red))
                                .padding(.vertical, 8)
                            
                            // Direct way to launch tutorial for testing
                            Button(action: {
                                UserDefaults.standard.set(false, forKey: "hasSeenTutorial")
                                NotificationCenter.default.post(name: Notification.Name("ShowTutorialOverlay"), object: nil)
                            }) {
                                Label("Show Tutorial Guide", systemImage: "questionmark.circle")
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 8)
                        }
                        
                        // Improve section header spacing
                        Section(header: 
                            Text("APP INFO")
                                .foregroundColor(.white)
                                .font(.headline)
                                .padding(.top, 16)
                                .padding(.bottom, 8)
                        ) {
                            NavigationLink(destination: AboutView()) {
                                Text("About Don't Pull Up")
                                    .padding(.vertical, 4)
                            }
                            
                            Button("Privacy Policy") {
                                showPrivacyPolicy = true
                            }
                            
                            Button("Terms of Service") {
                                showTermsOfService = true
                            }
                        }
                        
                        Section {
                            Button(action: {
                                showResetConfirmation = true
                            }) {
                                Text("Reset All Settings")
                                    .foregroundColor(.red)
                            }
                            .padding(.vertical, 4)
                        }
                        
                        Section {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) { // Increased spacing between version texts
                                    Text("Don't Pull Up")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    
                                    Text("Version 1.0.0 (Build 1)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(Color.black)
                    }
                    .background(Color.clear)
                    .hideListBackgroundIfNeeded()
                    .listStyle(PlainListStyle())
                }
                .padding(.top, 16) // Additional padding to prevent crowding with nav bar
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
            .alert("Reset Settings", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    resetSettings()
                }
            } message: {
                Text("Are you sure you want to reset all settings to their default values?")
            }
            // Sheet presentations
            .sheet(isPresented: $showPrivacyPolicy) {
                NavigationView {
                    PrivacyPolicyView()
                        .navigationBarItems(trailing: Button("Done") { showPrivacyPolicy = false })
                }
            }
            .sheet(isPresented: $showTermsOfService) {
                NavigationView {
                    TermsOfServiceView()
                        .navigationBarItems(trailing: Button("Done") { showTermsOfService = false })
                }
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private func resetSettings() {
        // Reset UI state
        notificationsEnabled = true
        locationTrackingEnabled = true
        darkModeEnabled = true
        hapticFeedbackEnabled = true
        
        // Reset all user defaults related to authentication and tutorial
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: "allowAnonymousAccess")
        defaults.set(true, forKey: "shouldShowInstructions")
        defaults.set(false, forKey: "hasSeenTutorial")
        
        // Notify the app to show tutorial when needed
        NotificationCenter.default.post(name: Notification.Name("ShowTutorialOverlay"), object: nil)
        
        // Reset location permission preferences (this won't affect actual system permissions)
        defaults.set(false, forKey: "userDeclinedLocationPermissions")
        
        // Sign out the user - this will trigger navigation back to the auth screen
        authState.signOut()
        
        // Show confirmation feedback
        let banner = UINotificationFeedbackGenerator()
        banner.notificationOccurred(.success)
        
        // Dismiss this view after a short delay to allow the haptic feedback to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Dismiss the settings view
            dismiss()
            
            // The RootView will automatically show the AuthView since the user is now signed out
        }
    }
}

struct AboutView: View {
    var body: some View {
        ZStack {
            Image("welcome_background")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .edgesIgnoringSafeArea(.all)
            
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
                
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("About Don't Pull Up")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Don't Pull Up is a community-driven safety app designed to help users identify and avoid potentially unsafe areas. The app allows users to mark locations where incidents have occurred, helping others stay informed and make safer decisions about their travel routes.")
                            .foregroundColor(.white)
                        
                        Text("Our mission is to create a safer community through shared awareness and information. By reporting incidents, you're helping others stay safe.")
                            .foregroundColor(.white)
                        
                        Text("The app is built with privacy in mind. All reports are anonymous by default, and we do not track your location unless you explicitly grant permission.")
                            .foregroundColor(.white)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// These views now moved to ResourceViews.swift

#Preview {
    SettingsView()
        .environmentObject(AuthState.shared)
}

extension View {
    @ViewBuilder
    func hideListBackgroundIfNeeded() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
} 