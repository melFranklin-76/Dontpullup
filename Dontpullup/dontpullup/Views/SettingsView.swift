import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SettingsView: View {
    @EnvironmentObject private var authState: AuthState
    @State private var notificationsEnabled = true
    @State private var locationTrackingEnabled = true
    @State private var hapticFeedbackEnabled = true
    @State private var showResetConfirmation = false
    @State private var showResetOnboardingConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isProcessingDeletion = false
    @State private var deletionError: String? = nil
    @State private var showDeletionError = false
    @ObservedObject private var onboardingManager = OnboardingManager.shared
    @Environment(\.presentationMode) var presentationMode
    
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
                    
                    Section(header: Text("Help & Tutorials").foregroundColor(.white)) {
                        Button(action: {
                            showResetOnboardingConfirmation = true
                        }) {
                            Text("Restart App Tour")
                                .foregroundColor(.white)
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
                    
                    // Delete Account Section
                    Section {
                        Button(action: {
                            showDeleteAccountConfirmation = true
                        }) {
                            HStack {
                                Spacer()
                                if isProcessingDeletion {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .red))
                                        .padding(.trailing, 10)
                                }
                                Text("Delete My Account")
                                    .foregroundColor(.red)
                                    .fontWeight(.bold)
                                Spacer()
                            }
                        }
                        .disabled(isProcessingDeletion)
                    } footer: {
                        Text("This will permanently delete your account and all associated data. This action cannot be undone.")
                            .font(.caption)
                            .foregroundColor(.gray)
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
            .alert("Restart App Tour", isPresented: $showResetOnboardingConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Restart", role: .none) {
                    resetOnboarding()
                }
            } message: {
                Text("This will restart the app tour tooltips the next time you return to the map. Continue?")
            }
            .alert("Delete Account", isPresented: $showDeleteAccountConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("Are you sure you want to permanently delete your account and all your data? This action cannot be undone.")
            }
            .alert("Error Deleting Account", isPresented: $showDeletionError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deletionError ?? "An unknown error occurred.")
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
    
    private func resetOnboarding() {
        onboardingManager.resetOnboarding()
        print("Onboarding tour will restart next time you return to the map.")
    }
    
    private func deleteAccount() {
        guard let user = Auth.auth().currentUser else {
            deletionError = "No user is currently signed in."
            showDeletionError = true
            return
        }
        
        isProcessingDeletion = true
        
        // 1. Delete all user data from Firestore
        deleteUserData(userId: user.uid) { firestoreError in
            if let error = firestoreError {
                // Handle Firestore deletion error
                handleDeletionError(error.localizedDescription)
                return
            }
            
            // 2. Delete user authentication account
            user.delete { authError in
                if let error = authError {
                    // Handle authentication deletion error
                    handleDeletionError(error.localizedDescription)
                    return
                }
                
                // Success - account fully deleted
                Task { @MainActor in
                    isProcessingDeletion = false
                    // Sign out and dismiss settings view
                    try? Auth.auth().signOut()
                    authState.isAuthenticated = false
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    
    private func deleteUserData(userId: String, completion: @escaping (Error?) -> Void) {
        let db = Firestore.firestore()
        let batch = db.batch()
        
        // Delete user pins
        db.collection("pins").whereField("userID", isEqualTo: userId).getDocuments { snapshot, error in
            if let error = error {
                completion(error)
                return
            }
            
            // Add each pin document to batch delete
            for document in snapshot?.documents ?? [] {
                batch.deleteDocument(document.reference)
            }
            
            // Delete user reports
            db.collection("reports").whereField("reportedBy", isEqualTo: userId).getDocuments { reportSnapshot, reportError in
                if let error = reportError {
                    completion(error)
                    return
                }
                
                // Add each report document to batch delete
                for document in reportSnapshot?.documents ?? [] {
                    batch.deleteDocument(document.reference)
                }
                
                // Commit all deletions in a single batch
                batch.commit { batchError in
                    completion(batchError)
                }
            }
        }
    }
    
    private func handleDeletionError(_ message: String) {
        Task { @MainActor in
            isProcessingDeletion = false
            deletionError = "Error deleting account: \(message)"
            showDeletionError = true
        }
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