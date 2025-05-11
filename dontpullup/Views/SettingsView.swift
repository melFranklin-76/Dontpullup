import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authState: AuthState
    @Environment(\.dismiss) private var dismiss
    @State private var notificationsEnabled = true
    @State private var locationTrackingEnabled = true
    @State private var darkModeEnabled = true
    @State private var hapticFeedbackEnabled = true
    @State private var showResetConfirmation = false
    
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
                            
                            NavigationLink(destination: PrivacyPolicyView()) {
                                Text("Privacy Policy")
                                    .padding(.vertical, 4)
                            }
                            
                            NavigationLink(destination: TermsOfServiceView()) {
                                Text("Terms of Service")
                                    .padding(.vertical, 4)
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
            .alert("Reset Settings", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    resetSettings()
                }
            } message: {
                Text("Are you sure you want to reset all settings to their default values?")
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

struct PrivacyPolicyView: View {
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
                        Text("Privacy Policy")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Last updated: June 2023")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("This Privacy Policy describes how Don't Pull Up collects, uses, and discloses your personal information when you use our mobile application.")
                            .foregroundColor(.white)
                        
                        Group {
                            Text("Information We Collect")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("We may collect certain personal information when you create an account, such as your email address, display name, and general location. We also collect information about the incidents you report, including location data and incident type.")
                                .foregroundColor(.white)
                        }
                        
                        Group {
                            Text("How We Use Your Information")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("We use the information we collect to provide, maintain, and improve our services, to communicate with you, and to protect our users and the public.")
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TermsOfServiceView: View {
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
                        Text("Terms of Service")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Last updated: June 2023")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("By downloading, installing, or using Don't Pull Up, you agree to be bound by these Terms of Service. If you do not agree to these terms, you may not use the app.")
                            .foregroundColor(.white)
                        
                        Group {
                            Text("User Content")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Users are responsible for the content they submit to the app. You agree not to submit false or misleading information, or content that is offensive, harmful, or violates the rights of others.")
                                .foregroundColor(.white)
                        }
                        
                        Group {
                            Text("Use of the Service")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("The app is intended to be used for informational purposes only. Don't Pull Up is not responsible for any actions taken based on the information provided through the app.")
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}

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