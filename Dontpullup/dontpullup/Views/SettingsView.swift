import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

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
                        
                        // Haptic feedback toggle with immediate effect
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Haptic Feedback", isOn: $hapticFeedbackEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .red))
                                .onChange(of: hapticFeedbackEnabled) { newValue in
                                    print("Settings: Toggling haptic feedback to \(newValue)")
                                    HapticManager.setEnabled(newValue)
                                    
                                    // If enabling, provide feedback to confirm it works
                                    if newValue {
                                        // Small delay to ensure the setting is applied
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            HapticManager.feedback(.medium)
                                        }
                                    }
                                }
                            
                            // Test button for haptic feedback
                            Button(action: {
                                print("Settings: Testing haptic feedback")
                                HapticManager.feedback(.medium)
                            }) {
                                Text("Test Haptic Feedback")
                                    .font(.footnote)
                                    .foregroundColor(.red)
                            }
                            .padding(.top, 2)
                        }
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
                // Full-screen progress overlay while an account-deletion is in flight
                if isProcessingDeletion {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView("Deleting your account…")
                            .progressViewStyle(CircularProgressViewStyle(tint: .red))
                            .foregroundColor(.white)
                        Text("This may take a moment.")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
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
        .onAppear {
            // Load current haptic feedback setting
            print("Settings: Loading haptic feedback setting from UserDefaults")
            hapticFeedbackEnabled = HapticManager.isEnabled
            print("Settings: Loaded hapticFeedbackEnabled = \(hapticFeedbackEnabled)")
        }
    }
    
    private func resetSettings() {
        notificationsEnabled = true
        locationTrackingEnabled = true
        hapticFeedbackEnabled = true
        // Update haptic feedback setting
        HapticManager.setEnabled(true)
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
        
        // Step 1 – purge all user-owned videos from Firebase Storage
        deleteUserVideos(userId: user.uid) { storageError in
            if let error = storageError {
                handleDeletionError(error.localizedDescription)
                return
            }
            
            // Step 2 – remove Firestore documents (pins, reports, etc.)
            deleteUserData(userId: user.uid) { firestoreError in
                if let error = firestoreError {
                    handleDeletionError(error.localizedDescription)
                    return
                }
                
                // Step 3 – delete the Firebase Auth account itself
                user.delete { authError in
                    if let error = authError {
                        handleDeletionError(error.localizedDescription)
                        return
                    }
                    
                    // ✅ Success – sign out & close settings
                    Task { @MainActor in
                        isProcessingDeletion = false
                        try? Auth.auth().signOut()
                        authState.isAuthenticated = false
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    /// Deletes all videos associated with the user's pins from Firebase Storage.
    /// - Parameter completion: Called on the **main thread** once all deletes finish (or on first error).
    private func deleteUserVideos(userId: String, completion: @escaping (Error?) -> Void) {
        let db = Firestore.firestore()
        
        // 1. Fetch the user's pins to extract their `videoURL`s
        db.collection("pins").whereField("userID", isEqualTo: userId).getDocuments { snapshot, error in
            if let error = error {
                DispatchQueue.main.async { completion(error) }
                return
            }
            
            let urls: [String] = snapshot?.documents.compactMap { $0.data()["videoURL"] as? String } ?? []
            
            guard !urls.isEmpty else {
                // Nothing to delete
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            // 2. Create storage-references
            let refs = urls.map { Storage.storage().reference(forURL: $0) }
            
            // Concurrency limiter – at most 5 simultaneous deletions
            let semaphore = DispatchSemaphore(value: 5)
            let group = DispatchGroup()
            // Capture first error (if any)
            var firstError: Error?
            
            for ref in refs {
                group.enter()
                DispatchQueue.global(qos: .utility).async {
                    semaphore.wait()
                    ref.delete { error in
                        if let error = error, firstError == nil {
                            firstError = error
                        }
                        semaphore.signal()
                        group.leave()
                    }
                }
            }
            
            group.notify(queue: .main) {
                completion(firstError)
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
                    Text("DON'T PULL UP, ON GRANDMA! – COMMUNITY GUIDELINES")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.bottom, 8)
                    
                    Text("This platform is built on truth, visibility, and accountability. These rules help keep that mission alive:")
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.bottom, 8)
                    
                    Group {
                        Text("1. BE TRUTHFUL")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        
                        Text("• Only upload real interactions you personally recorded in public spaces.\n• Do not stage, script, or fake scenarios.")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        
                        Text("2. RESPECT PRIVACY")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        
                        Text("• Never film in private areas or share private details like names, home addresses, or license plates without blurring.")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        
                        Text("3. NO HATE OR HARASSMENT")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        
                        Text("• No racist, sexist, or threatening language or behavior — in videos or captions.")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                    }
                    
                    Group {
                        Text("4. REPORTING CONTENT")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        
                        Text("• Use the flag button if you believe a video is fake, misleading, or harmful.\n• Leave your email if you want a follow-up. We investigate every report.\n• All reported content is reviewed manually. Content that violates these guidelines may be removed at our discretion.")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        
                        Text("5. STAY ACCOUNTABLE")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        
                        Text("• Violating these guidelines may result in content removal or account suspension.\n• Repeated abuse can lead to permanent bans.\n• Users may contact us to appeal any moderation decisions.")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        
                        Text("6. USE RESPONSIBLY")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        
                        Text("• This app is for exposing real-world mistreatment, not for retaliation, shaming, or personal attacks.")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                    }
                    
                    Text("We're here to shine a light — not start a fire. Let's keep it real, respectful, and righteous.")
                        .font(.body.italic())
                        .foregroundColor(.white)
                        .padding(.bottom, 8)
                    
                    Text("Contact us at: contact@dontpullup.com")
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
                    Text("DON'T PULL UP, ON GRANDMA! – PRIVACY POLICY")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.bottom, 8)
                    
                    Text("Effective Date: 5/1/25")
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.bottom, 8)
                    
                    Text("Your privacy is important to us. This Privacy Policy explains how we collect, use, and protect your information.")
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.bottom, 8)
                    
                    Group {
                        Text("1. INFORMATION WE COLLECT")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        
                        Text("• Account info (e.g., email, username) for registered users\n• Location data (only while using the app, and only for pin-drop purposes)\n• Metadata from uploaded videos (to verify authenticity)")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        
                        Text("2. HOW WE USE YOUR DATA")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        
                        Text("• To allow users to upload videos and drop pins nearby\n• To verify and moderate content\n• To communicate with users if a video is flagged or reported")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        
                        Text("3. WHO SEES YOUR DATA")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        
                        Text("• Anonymous users can view content, but only registered users can post\n• We do not sell or share your data with third parties")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                    }
                    
                    Group {
                        Text("4. USER CONTROLS")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        
                        Text("• You can delete your account at any time by contacting us\n• Location use is only active while using the pin-drop feature and not stored afterward")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        
                        Text("5. DATA SECURITY")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        
                        Text("We use secure encryption and access control practices to protect your information.")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        
                        Text("6. CHILDREN'S PRIVACY")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        
                        Text("We do not knowingly allow children under 13 to use the app. If we become aware, we will remove the account.")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                    }
                    
                    Text("Contact us at: contact@dontpullup.com")
                        .font(.body)
                        .foregroundColor(.white)
                    
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
                    Text("DON'T PULL UP, ON GRANDMA! – TERMS OF SERVICE")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.bottom, 8)
                    
                    Text("Effective Date: 5/1/25")
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.bottom, 8)
                    
                    Text("Welcome to Don't Pull Up, on Grandma! (\"the App\"), a platform operated by RESCH & RALSTON R.I.P. TRUST. These Terms of Service govern your use of our App and services.")
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.bottom, 8)
                    
                    Group {
                        Text("1. WHO MAY USE THE APP")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        
                        Text("Only registered users may upload videos. By registering, you confirm that:")
                            .font(.body)
                            .foregroundColor(.white)
                        
                        Text("• You are at least 13 years old.\n• You will only record and upload video of your own interactions in public spaces.\n• You agree to abide by these Terms and our Community Guidelines.")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        
                        Text("2. CONTENT OWNERSHIP AND RESPONSIBILITY")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        
                        Text("• You retain ownership of your uploaded content but grant us a license to display, distribute, and host it within the app.\n• You are solely responsible for the content you upload.\n• Videos must not include private information (e.g., full names, addresses) or be filmed in private areas (e.g., restrooms, staff-only areas).")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                    }
                    
                    Group {
                        Text("3. LOCATION RESTRICTION")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        
                        Text("Pin drops are only allowed within 200 feet of your device's location. Any attempt to spoof or falsify this data may result in account removal.")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        
                        Text("4. NO ILLEGAL OR MANIPULATED CONTENT")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        
                        Text("• You may not upload videos that are edited to mislead or misrepresent the truth.\n• Our system checks metadata to detect manipulated content.\n• Uploading falsified or defamatory videos may result in permanent suspension and legal consequences.")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                    }
                    
                    Group {
                        Text("5. REPORTING AND DISPUTES")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        
                        Text("• Every video includes a flag option.\n• Users can report objectionable or potentially false content by submitting their email.\n• We review all flagged content and may contact the reporting party for more information.")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        
                        Text("6. ACCOUNT TERMINATION")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        
                        Text("We reserve the right to suspend or remove any account that violates these terms, posts harmful content, or misuses the platform.")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        
                        Text("7. MODIFICATION")
                            .font(.title3.bold())
                            .foregroundColor(.yellow)
                        
                        Text("We may update these Terms from time to time. Continued use of the App means you agree to the latest version.")
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