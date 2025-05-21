import FirebaseAuth
import SwiftUI
import OSLog
import FirebaseFirestore
import FirebaseStorage

private let authLogger = Logger(subsystem: "com.dontpullup", category: "Authentication")

class AuthState: ObservableObject {
    // Singleton pattern
    static let shared = AuthState()
    
    // Published properties
    @Published var isAuthenticated: Bool = false
    @Published var isInitialized: Bool = false
    @Published var isLoading: Bool = true
    @Published var currentUser: User?
    @Published var isAnonymous: Bool = false
    @Published var shouldShowInstructions: Bool = true
    
    private var handle: AuthStateDidChangeListenerHandle?
    
    private init() {
        authLogger.info("Initializing authentication state observer")
        shouldShowInstructions = UserDefaults.standard.bool(forKey: "shouldShowInstructions")

        setupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        // Remove existing listener if any
        if let existingHandle = handle {
            Auth.auth().removeStateDidChangeListener(existingHandle)
        }
        
        // Setup new listener
        handle = Auth.auth().addStateDidChangeListener { [weak self] (auth: Auth, user: User?) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if !self.isInitialized {
                    self.isInitialized = true
                    // Add a short delay to allow splash screen to display
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.isLoading = false
                    }
                    authLogger.info("Initial auth state received")
                }
                
                self.currentUser = user
                self.isAuthenticated = user != nil && (!user!.isAnonymous || UserDefaults.standard.bool(forKey: "allowAnonymousAccess"))
                self.isAnonymous = user?.isAnonymous ?? false
                
                if let user = user {
                    authLogger.info("User signed in - ID: \(user.uid), Anonymous: \(user.isAnonymous)")
                    if let email = user.email {
                        authLogger.info("User email: \(email)")
                    }
                    
                    // Reset instructions for anonymous users
                    if user.isAnonymous {
                        self.shouldShowInstructions = true
                        UserDefaults.standard.set(true, forKey: "shouldShowInstructions")
                    }
                    
                    // Refresh the user's token to ensure it's valid
                    Task {
                        do {
                            _ = try await user.getIDToken(forcingRefresh: true)
                        } catch {
                            authLogger.error("Failed to refresh user token: \(error.localizedDescription)")
                        }
                    }
                } else {
                    authLogger.info("User signed out")
                    // Reset instructions flag when user signs out
                    self.shouldShowInstructions = true
                    UserDefaults.standard.set(true, forKey: "shouldShowInstructions")
                }
            }
        }
    }
    
    var isSignedIn: Bool {
        return isAuthenticated
    }
    
    var isRegisteredUser: Bool {
        return currentUser != nil && !currentUser!.isAnonymous
    }
    
    // MARK: - Async Bridged Authentication Methods
    
    /// Provides an async/await wrapper around the completion-based signInAnonymously method
    func signInAnonymouslyAsync() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            signInAnonymously { result in
                switch result {
                case .success():
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Provides an async/await wrapper around the completion-based signIn method
    func signInAsync(email: String, password: String) async throws -> User {
        return try await withCheckedThrowingContinuation { continuation in
            signIn(email: email, password: password) { result in
                switch result {
                case .success(let user):
                    continuation.resume(returning: user)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Provides an async/await wrapper around the completion-based signUp method
    func signUpAsync(email: String, password: String, zipCode: String) async throws -> User {
        return try await withCheckedThrowingContinuation { continuation in
            signUp(email: email, password: password, zipCode: zipCode) { result in
                switch result {
                case .success(let user):
                    continuation.resume(returning: user)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Original Authentication Methods
    
    // Authentication methods
    func signInAnonymously(completion: @escaping (Result<Void, Error>) -> Void) {
        authLogger.info("Starting anonymous authentication...")
        Auth.auth().signInAnonymously { authResult, error in
            if let error = error {
                authLogger.error("Anonymous authentication failed: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // Set flag to allow anonymous access (could be toggled by user preference)
            UserDefaults.standard.set(true, forKey: "allowAnonymousAccess")
            authLogger.info("Anonymous authentication successful")
            completion(.success(()))
        }
    }

    func signIn(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        authLogger.info("Signing in with email...")
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                authLogger.error("Email sign-in failed: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let user = authResult?.user else {
                let error = NSError(domain: "AuthState", code: -1, userInfo: [NSLocalizedDescriptionKey: "User is nil after sign in"])
                authLogger.error("Email sign-in failed: User is nil")
                completion(.failure(error))
                return
            }
            
            // Reset instructions flag for new session
            self.shouldShowInstructions = true
            UserDefaults.standard.set(true, forKey: "shouldShowInstructions")
            
            authLogger.info("Email sign-in successful")
            completion(.success(user))
        }
    }

    func signUp(email: String, password: String, zipCode: String, completion: @escaping (Result<User, Error>) -> Void) {
        authLogger.info("Creating new account...")
        
        // Validate inputs before proceeding
        guard !email.isEmpty, !password.isEmpty, !zipCode.isEmpty else {
            let error = NSError(domain: "AuthState", code: -2, userInfo: [NSLocalizedDescriptionKey: "Email, password, and zip code cannot be empty"])
            authLogger.error("Account creation failed: Empty fields")
            completion(.failure(error))
            return
        }
        
        // Skip the deprecated email check and proceed directly with account creation
        // Firebase will return an error if the email is already in use
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else {
                completion(.failure(NSError(domain: "AuthState", code: -4, userInfo: [NSLocalizedDescriptionKey: "Authentication context was deallocated"])))
                return
            }
            
            if let error = error as NSError? {
                // Handle specific Firebase error for email already in use
                if error.domain == AuthErrorDomain && error.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                    authLogger.error("Account creation failed: Email already in use")
                    completion(.failure(NSError(domain: "AuthState", code: -3, userInfo: [NSLocalizedDescriptionKey: "This email is already in use"])))
                    return
                } else {
                    authLogger.error("Account creation failed: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
            }
            
            guard let user = authResult?.user else {
                let error = NSError(domain: "AuthState", code: -1, userInfo: [NSLocalizedDescriptionKey: "User is nil after sign up"])
                authLogger.error("Account creation failed: User is nil")
                completion(.failure(error))
                return
            }
            
            // Show instructions for new users
            self.shouldShowInstructions = true
            UserDefaults.standard.set(true, forKey: "shouldShowInstructions")
            
            // Create user profile with zip code in Firestore
            let db = Firestore.firestore()
            let userRef = db.collection("users").document(user.uid)
            let userData: [String: Any] = [
                "uid": user.uid,
                "email": email,
                "isAnonymous": false,
                "zipCode": zipCode,
                "createdAt": FieldValue.serverTimestamp(),
                "lastLogin": FieldValue.serverTimestamp()
            ]
            
            // Log success before Firestore operation
            authLogger.info("User created in Auth successfully: \(user.uid)")
            
            // Create Firestore profile without blocking account creation success
            userRef.setData(userData, merge: true) { error in
                if let error = error {
                    authLogger.error("Failed to create Firestore profile: \(error.localizedDescription)")
                    // We don't fail the signup process for Firestore issues
                } else {
                    authLogger.info("User profile created in Firestore successfully")
                }
            }
            
            // Return success since the Auth part worked
            completion(.success(user))
        }
    }

    func signOut() {
        authLogger.info("[AuthState] signOut() method called.")
        // Instead of using a do-catch with no try statements, directly call the method
        // and handle any errors with a safe unwrapping
        
        do {
            try Auth.auth().signOut() // This will trigger the listener to update state too
        } catch {
            authLogger.error("Error signing out from Firebase: \(error.localizedDescription)")
        }
        
        // Synchronously update state properties on the main thread for immediate UI effect.
        // The listener will also run and confirm this state.
        DispatchQueue.main.async {
            self.currentUser = nil
            self.isAuthenticated = false
            self.isAnonymous = false
            self.shouldShowInstructions = true
            UserDefaults.standard.set(true, forKey: "shouldShowInstructions")
            UserDefaults.standard.set(false, forKey: "allowAnonymousAccess") // Crucial for anonymous logic
            authLogger.info("[AuthState] Synchronously updated state properties after signOut call.")
        }
    }
    
    func dismissInstructions() {
        shouldShowInstructions = false
        UserDefaults.standard.set(false, forKey: "shouldShowInstructions")
    }
    
    deinit {
        if let handle = handle {
            authLogger.info("Removing auth state listener")
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    /// Deletes the current user's account and all associated data
    @MainActor
    func deleteAccountAndData() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthState", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authenticated user found."])
        }
        let uid = user.uid
        let db = Firestore.firestore()
        let storage = Storage.storage()
        // 1. Delete all pins and their videos
        let pinsSnapshot = try await db.collection("pins").whereField("userId", isEqualTo: uid).getDocuments()
        for doc in pinsSnapshot.documents {
            let pinId = doc.documentID
            // Delete video from storage if exists
            let videoURL = doc.data()["videoURL"] as? String ?? ""
            if !videoURL.isEmpty, let url = URL(string: videoURL), url.path.contains("videos/") {
                let ref = storage.reference(forURL: videoURL)
                do { 
                    try await ref.delete() 
                } catch { 
                    print("[Delete] Could not delete video: \(error)") 
                }
            }
            // Delete pin document
            try await db.collection("pins").document(pinId).delete()
        }
        // 2. Delete user document
        try await db.collection("users").document(uid).delete()
        // 3. Delete user from Firebase Auth
        do {
            try await user.delete()
            // 4. Sign out and update state ONLY if user was deleted
            signOut()
        } catch let error as NSError {
            if error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                print("[Delete] Re-authentication required before deleting account.")
                throw NSError(domain: "AuthState", code: 403, userInfo: [NSLocalizedDescriptionKey: "For security, please sign in again before deleting your account."])
            } else {
                print("[Delete] Error deleting user: \(error)")
                throw error
            }
        }
    }
}

