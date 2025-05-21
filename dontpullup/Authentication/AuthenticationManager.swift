@preconcurrency import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
final class AuthenticationManager: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isAnonymous = false
    @Published var errorMessage: String?
    @Published var isProcessing = false
    
    static let shared = AuthenticationManager()
    private var handle: AuthStateDidChangeListenerHandle?
    
    init() {
        setupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                self?.isAnonymous = user?.isAnonymous ?? false
                print("AuthenticationManager: Auth state changed - User: \(user?.uid ?? "none"), Anonymous: \(user?.isAnonymous ?? false)")
            }
        }
    }
    
    func signIn(email: String, password: String) async throws {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.currentUser = result.user
            self.isAuthenticated = true
            self.isAnonymous = result.user.isAnonymous
            self.errorMessage = nil
            print("AuthenticationManager: Sign in successful - User: \(result.user.uid)")
            
            try await updateUserLastLogin(for: result.user)
        } catch {
            self.errorMessage = "Sign in failed: \(error.localizedDescription)"
            throw error
        }
    }
    
    func signUp(email: String, password: String) async throws {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            self.currentUser = result.user
            self.isAuthenticated = true
            self.isAnonymous = false
            self.errorMessage = nil
            print("AuthenticationManager: Sign up successful - User: \(result.user.uid)")
            
            try await createUserProfile(for: result.user, zipCode: "")
        } catch {
            self.errorMessage = "Sign up failed: \(error.localizedDescription)"
            throw error
        }
    }
    
    func signInAnonymously() async throws {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let result = try await Auth.auth().signInAnonymously()
            self.currentUser = result.user
            self.isAuthenticated = true
            self.isAnonymous = true
            self.errorMessage = nil
            print("AuthenticationManager: Anonymous sign in successful - User: \(result.user.uid)")
            
            try await createUserProfile(for: result.user, zipCode: "")
        } catch {
            self.errorMessage = "Anonymous sign in failed: \(error.localizedDescription)"
            throw error
        }
    }
    
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            self.currentUser = nil
            self.isAuthenticated = false
            self.isAnonymous = false
            self.errorMessage = nil
            print("AuthenticationManager: Sign out successful")
        } catch {
            self.errorMessage = "Sign out failed: \(error.localizedDescription)"
            throw error
        }
    }
    
    func convertAnonymousAccount(email: String, password: String) async throws {
        isProcessing = true
        defer { isProcessing = false }
        
        guard let user = Auth.auth().currentUser, user.isAnonymous else {
            let error = NSError(domain: "AuthenticationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No anonymous user to convert"])
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        
        do {
            let result = try await user.link(with: credential)
            self.currentUser = result.user
            self.isAuthenticated = true
            self.isAnonymous = false
            
            try await updateUserProfileAfterConversion(for: result.user, email: email)
            
            print("AuthenticationManager: Anonymous account converted successfully - User: \(result.user.uid)")
        } catch {
            self.errorMessage = "Account conversion failed: \(error.localizedDescription)"
            throw error
        }
    }
    
    func createUserProfile(for user: User, zipCode: String) async throws {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)
        let userData: [String: Any] = [
            "uid": user.uid,
            "email": user.email ?? "",
            "isAnonymous": user.isAnonymous,
            "zipCode": zipCode,
            "createdAt": FieldValue.serverTimestamp(),
            "lastLogin": FieldValue.serverTimestamp()
        ]
        try await userRef.setData(userData, merge: true)
        print("AuthenticationManager: User profile created in Firestore - User: \(user.uid)")
    }
    
    private func updateUserProfileAfterConversion(for user: User, email: String) async throws {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)
        
        let userData: [String: Any] = [
            "email": email,
            "isAnonymous": false,
            "convertedAt": FieldValue.serverTimestamp(),
            "lastLogin": FieldValue.serverTimestamp()
        ]
        
        try await userRef.updateData(userData)
        print("AuthenticationManager: User profile updated after conversion - User: \(user.uid)")
    }
    
    private func updateUserLastLogin(for user: User) async throws {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)
        
        let userData: [String: Any] = [
            "lastLogin": FieldValue.serverTimestamp()
        ]
        
        try await userRef.updateData(userData)
    }
    
    func isEmailInUse(_ email: String) async -> Bool {
        do {
            // The recommended approach when fetchSignInMethods is deprecated
            // is to attempt to create a user with the email and catch the error
            // This is more reliable than fetchSignInMethods which can be affected
            // by Email Enumeration Protection
            
            // First check if the email is valid
            if !isValidEmail(email) {
                return false
            }
            
            // Create a random password that's unlikely to be used by a real account
            let randomPassword = UUID().uuidString + UUID().uuidString
            
            // Try to create an account with the email
            try await Auth.auth().createUser(withEmail: email, password: randomPassword)
            
            // If we get here, the email is available (no account exists)
            // We should delete the temporary account we just created
            if let tempUser = Auth.auth().currentUser {
                try await tempUser.delete()
                // Sign out to clean up
                try Auth.auth().signOut()
                // Restore the previous auth state
                if self.isAnonymous {
                    try await self.signInAnonymously()
                }
            }
            
            return false // Email is not in use
        } catch let error as NSError {
            // Check for the specific error code that indicates the email is already in use
            // Error code 17007 means the email is already in use
            if error.domain == AuthErrorDomain, error.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                return true // Email is in use
            }
            
            // For other errors, we should log them but assume the email might not be in use
            print("Error checking if email is in use: \(error.localizedDescription)")
            return false
        }
    }
    
    // Helper to validate email format
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
