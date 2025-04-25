import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authState: AuthState
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
                    Form {
                        Section(header: Text("General").foregroundColor(.white)) {
                            Toggle("Enable Notifications", isOn: $notificationsEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .red))
                            
                            Toggle("Location Tracking", isOn: $locationTrackingEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .red))
                            
                            Toggle("Dark Mode", isOn: $darkModeEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .red))
                                .disabled(true) // Disabled as app is dark mode only
                            
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
                                Text("Reset All Settings")
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Section {
                            HStack {
                                Spacer()
                                VStack(spacing: 4) {
                                    Text("Don't Pull Up")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    
                                    Text("Version 1.0.0 (Build 1)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }
                        }
                        .listRowBackground(Color.black)
                    }
                    .background(Color.clear)
                    .hideListBackgroundIfNeeded()
                    .listStyle(PlainListStyle())
                }
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
        notificationsEnabled = true
        locationTrackingEnabled = true
        darkModeEnabled = true
        hapticFeedbackEnabled = true
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
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Privacy Policy")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Last Updated: April 24, 2025")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("We prioritize your privacy. Here's how we handle your data:")
                            .foregroundColor(.white)
                        
                        Group {
                            Text("1. Data Collected")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("- Videos and location pins you upload.")
                                .foregroundColor(.white)
                            Text("- Email or Apple Sign-In data for your account.")
                                .foregroundColor(.white)
                            Text("- Optional analytics on app usage.")
                                .foregroundColor(.white)
                        }
                        
                        Group {
                            Text("2. Usage")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("- To display your content and operate the app.")
                                .foregroundColor(.white)
                            Text("- To secure your account and improve features.")
                                .foregroundColor(.white)
                        }

                        Group {
                            Text("3. Sharing")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("- Videos are public; personal data stays private except for operational needs (e.g., AWS storage).")
                                .foregroundColor(.white)
                        }
                        
                        Group {
                            Text("4. Security")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("- Encrypted with HTTPS and AES-256.")
                                .foregroundColor(.white)
                        }
                        
                        Group {
                            Text("5. Your Rights")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("- Delete your content or account anytime via settings.")
                                .foregroundColor(.white)
                        }
                        
                        Group {
                            Text("6. Contact")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("- support@dontpullupongrandma.com")
                                .foregroundColor(.white)
                                .tint(.blue)
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
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Terms of Service")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Last Updated: April 24, 2025")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("By using Don't Pull Up on Grandma (the App), you agree to these Terms:")
                            .foregroundColor(.white)
                        
                        Group {
                            Text("1. Eligibility")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("- Must be 13+; under 18 requires parental consent.")
                                .foregroundColor(.white)
                        }
                        
                        Group {
                            Text("2. Your Responsibilities")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("- You're accountable for your videos complying with laws and our Community Guidelines.")
                                .foregroundColor(.white)
                            Text("- You grant us a non-exclusive license to host and display your content.")
                                .foregroundColor(.white)
                        }
                        
                        Group {
                            Text("3. Moderation")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("- We may remove content or suspend accounts for violations.")
                                .foregroundColor(.white)
                        }
                        
                        Group {
                            Text("4. Legal Disclaimer")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("- You upload at your own risk and must ensure legal compliance (e.g., filming laws).")
                                .foregroundColor(.white)
                        }
                        
                        Group {
                            Text("5. Contact")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("- Email support@dontpullupongrandma.com for issues.")
                                .foregroundColor(.white)
                                .tint(.blue)
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