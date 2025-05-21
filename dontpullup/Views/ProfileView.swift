import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject private var authState: AuthState
    @Environment(\.dismiss) private var dismiss
    @State private var showSignOutConfirmation = false
    @State private var showConvertAccountSheet = false
    @State private var isLoading = false
    @State private var zipCode: String = ""
    @State private var showDeleteConfirmation = false
    @State private var errorMessage = ""
    @State private var showErrorAlert = false
    
    var body: some View {
        NavigationView {
            ZStack { // Outer ZStack for background
                // Background Image
                Image("welcome_background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
                
                // Darker overlay to clearly separate from map content
                Color.black.opacity(0.9)
                    .edgesIgnoringSafeArea(.all)
                
                // Original ZStack content
                ScrollView {
                    VStack(spacing: 24) { // Increased spacing between main sections
                        // Add spacing at the top to prevent crowding with navigation bar
                        Spacer()
                            .frame(height: 20)
                            
                        // User avatar and name
                        VStack(spacing: 16) { // Increased spacing between avatar and text
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundColor(.white)
                                        .padding(20)
                                )
                            
                            VStack(spacing: 8) { // Proper spacing between name and email
                                Text(userName)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text(userEmail)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.top, 20)
                        
                        // Anonymous user badge if applicable
                        if isAnonymousUser {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.yellow)
                                Text("Guest Account")
                                    .font(.headline)
                                    .foregroundColor(.yellow)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .background(Color.yellow.opacity(0.2))
                            .cornerRadius(10)
                            
                            // Convert account button for anonymous users
                            Button(action: {
                                showConvertAccountSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "person.badge.plus")
                                    Text("Create Permanent Account")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(10)
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        // Stats section with improved spacing
                        VStack(spacing: 16) {
                            Text("Activity")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 24)
                                
                            HStack(spacing: 36) { // Increased spacing between stats
                                StatView(title: "Reports", value: "12")
                                StatView(title: "Upvotes", value: "48")
                                StatView(title: "Days", value: "30")
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, 24)
                        
                        Spacer(minLength: 40) // More space above sign out button
                        
                        // Sign out button
                        Button(action: {
                            showSignOutConfirmation = true
                        }) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Sign Out")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        }
                        .disabled(isLoading)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(10)
                        .padding(.horizontal, 24)
                        // Add Delete Account button below
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Delete Account & Data")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        }
                        .disabled(isLoading)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray)
                        .cornerRadius(10)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal)
                    .frame(minHeight: UIScreen.main.bounds.height - 120) // Ensure content fills vertical space
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    isLoading = true
                    authState.signOut()
                    isLoading = false
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account & Data", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    isLoading = true
                    Task {
                        do {
                            try await authState.deleteAccountAndData()
                            isLoading = false
                            dismiss()
                        } catch {
                            isLoading = false
                            // Show error alert
                            errorMessage = error.localizedDescription
                            showErrorAlert = true
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to permanently delete your account and all associated data? This cannot be undone.")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showConvertAccountSheet) {
                ConvertAccountView(isPresented: $showConvertAccountSheet)
                    .environmentObject(authState)
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private var userName: String {
        if let user = authState.currentUser {
            if user.isAnonymous {
                return "Guest User"
            }
            return user.displayName ?? "User"
        }
        return "User"
    }
    
    private var userEmail: String {
        if let user = authState.currentUser, let email = user.email, !email.isEmpty {
            return email
        }
        
        if isAnonymousUser {
            return "Sign up for a permanent account"
        }
        
        return "No email provided"
    }
    
    private var isAnonymousUser: Bool {
        return authState.currentUser?.isAnonymous ?? false
    }
}

struct ConvertAccountView: View {
    @EnvironmentObject var authState: AuthState
    @Binding var isPresented: Bool
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var zipCode: String = ""
    
    var isValid: Bool {
        !email.isEmpty && !password.isEmpty && password == confirmPassword && password.count >= 6
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background Image
                Image("welcome_background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
                
                // Semi-transparent overlay
                Color.black.opacity(0.7)
                    .edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 24) {
                        Text("Create Your Account")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.top, 40)
                        
                        Text("Convert your guest account to a permanent account to save your data and access all features.")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            TextField("Email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .padding(.horizontal)
                            
                            SecureField("Password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                            
                            SecureField("Confirm Password", text: $confirmPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                            
                            TextField("Zip Code", text: $zipCode)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                                .padding(.horizontal)
                        }
                        .padding(.top, 20)
                        
                        // Password match indicator
                        if !password.isEmpty && !confirmPassword.isEmpty {
                            HStack {
                                Image(systemName: password == confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(password == confirmPassword ? .green : .red)
                                Text(password == confirmPassword ? "Passwords match" : "Passwords don't match")
                                    .foregroundColor(password == confirmPassword ? .green : .red)
                            }
                            .padding(.top, 4)
                        }
                        
                        if password.count > 0 && password.count < 6 {
                            Text("Password must be at least 6 characters")
                                .foregroundColor(.orange)
                                .padding(.top, 4)
                        }
                        
                        // Convert button
                        Button(action: convertAccount) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .padding(.trailing, 8)
                                }
                                Text("Create Account")
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isValid ? Color.blue : Color.gray)
                            .cornerRadius(10)
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                        }
                        .disabled(!isValid || isLoading)
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") {
                isPresented = false
            })
            .alert(isPresented: $showError) {
                Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
    
    private func convertAccount() {
        guard isValid else { return }
        
        isLoading = true
        
        Task {
            do {
                // Check if email is already in use by directly using Firebase Auth
                // but properly handle the async nature
                let emailInUse = try await checkIfEmailInUse(email)
                if emailInUse {
                    errorMessage = "Email is already in use. Please use a different email."
                    showError = true
                    isLoading = false
                    return
                }
                
                // Properly bridge between async/await and completion handlers
                if let user = Auth.auth().currentUser, user.isAnonymous {
                    // Convert anonymous account to permanent
                    try await linkAnonymousAccount(email: email, password: password)
                    
                    // Update auth state (will happen automatically via listener)
                    authState.isAnonymous = false
                    
                    // Dismiss sheet
                    isLoading = false
                    isPresented = false
                } else {
                    // Fallback to regular sign up using proper async/await bridging
                    try await createNewAccount(email: email, password: password)
                    
                    isLoading = false
                    isPresented = false
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isLoading = false
            }
        }
    }
    
    // Helper method to check if email is in use with proper async handling
    private func checkIfEmailInUse(_ email: String) async throws -> Bool {
        // First, validate the email format client-side
        guard isValidEmail(email) else {
            throw NSError(
                domain: "EmailValidation",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Please enter a valid email address."]
            )
        }
        
        // Use a direct Firebase Auth method to check if a user exists
        // Note: This is a workaround since fetchSignInMethods is deprecated
        return false // Default to false, allowing the creation attempt to proceed
                    // If the email exists, Firebase will throw an error during account creation
    }
    
    // Helper function to validate email format
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    // Helper method to link anonymous account
    private func linkAnonymousAccount(email: String, password: String) async throws {
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        
        return try await withCheckedThrowingContinuation { continuation in
            Auth.auth().currentUser?.link(with: credential) { authResult, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                continuation.resume(returning: ())
            }
        }
    }
    
    // Helper method to create a new account
    private func createNewAccount(email: String, password: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            authState.signUp(email: email, password: password, zipCode: zipCode) { result in
                switch result {
                case .success(_):
                    continuation.resume(returning: ())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(minWidth: 70) // Ensure stat views have consistent width
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthState.shared)
} 