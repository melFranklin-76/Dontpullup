import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authState: AuthState
    @State private var notificationsEnabled = true
    @State private var locationTrackingEnabled = true
    @State private var hapticFeedbackEnabled = true
    @State private var showResetConfirmation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                List {
                    Section(header: Text("General").foregroundColor(.white)) {
                        Toggle("Enable Notifications", isOn: $notificationsEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: .red))
                        
                        Toggle("Location Tracking", isOn: $locationTrackingEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: .red))
                        
                        Toggle("Dark Mode", isOn: .constant(true))
                            .toggleStyle(SwitchToggleStyle(tint: .red))
                            .disabled(true)
                        
                        Toggle("Haptic Feedback", isOn: $hapticFeedbackEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: .red))
                    }
                    
                    Section(header: Text("App Info").foregroundColor(.white)) {
                        NavigationLink(destination: AboutView()) {
                            Text("About Don't Pull Up")
                        }
                        
                        NavigationLink(destination: PrivacyPolicyView()) {
                            Text("Privacy Policy")
                        }
                        
                        NavigationLink(destination: TermsOfServiceView()) {
                            Text("Terms of Service")
                        }
                    }
                    
                    Section {
                        Button(action: {
                            showResetConfirmation = true
                        }) {
                            HStack {
                                Spacer()
                                Text("Reset All Settings")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    }
                    
                    Section {
                        VStack(spacing: 4) {
                            Text("Don't Pull Up")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            Text("Version 1.0.0 (Build 1)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(InsetGroupedListStyle())
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
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
        notificationsEnabled = true
        locationTrackingEnabled = true
        hapticFeedbackEnabled = true
        print("Settings reset to defaults.")
    }
}

struct AboutView: View {
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("About Don't Pull Up")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.bottom, 8)
                    
                    Text("Don't Pull Up is a community-driven safety app designed to help users identify and avoid potentially unsafe areas. The app allows users to mark locations where incidents have occurred, helping others stay informed.")
                        .font(.body)
                        .foregroundColor(.white)
                    
                    Text("Our Mission")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .padding(.top, 8)
                    
                    Text("Create a safer community through shared awareness and information. By reporting incidents, you're helping others stay safe.")
                        .font(.body)
                        .foregroundColor(.white)
                    
                    Text("Privacy")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .padding(.top, 8)
                    
                    Text("The app is built with privacy in mind. All reports are anonymous by default, and we do not track your location unless you explicitly grant permission.")
                        .font(.body)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Privacy Policy")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.bottom, 8)
                    
                    Group {
                        Text("Data Collection")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        
                        Text("We collect limited data necessary for app functionality: account information, location data (only when you use the app), and content you choose to share.")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        
                        Text("Your Privacy Choices")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        
                        Text("You can limit location data collection through settings. You can request deletion of your account and associated data by contacting support.")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        
                        Text("Data Usage")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        
                        Text("Your data helps improve app functionality and provide location-based safety information. We do not sell your personal information to third parties.")
                            .font(.body)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TermsOfServiceView: View {
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Terms of Service")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.bottom, 8)
                    
                    Group {
                        Text("User Responsibilities")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        
                        Text("By using this app, you agree to only upload accurate and legally compliant content. You are responsible for all content you share through the app.")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        
                        Text("Content Guidelines")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        
                        Text("Do not upload false, misleading, illegal, or harmful content. We reserve the right to remove content that violates these terms without notice.")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        
                        Text("Service Modifications")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        
                        Text("We may modify or discontinue services at any time. We are not liable for any modification, suspension, or discontinuation of the service.")
                            .font(.body)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthState.shared)
} 