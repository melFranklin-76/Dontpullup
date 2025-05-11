import FirebaseAuth
import SwiftUI
import OSLog

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

        // TEMPORARY DEBUGGING: Force sign-out on init.
        // This should ensure any persisted Firebase session is cleared BEFORE the first listener event
        // might report an auto-logged-in user.
        // The listener setup should happen AFTER this forced sign-out.
        authLogger.info("[AuthState DEBUG] Attempting to force sign-out at the very start of init to clear any persisted Firebase user.")
        do {
            try Auth.auth().signOut()
            authLogger.info("[AuthState DEBUG] Forced sign-out successful (or no user was present).")
        } catch {
            authLogger.error("[AuthState DEBUG] Error during initial forced sign-out: \(error.localizedDescription)")
        }
        // END TEMPORARY DEBUGGING

        setupAuthStateListener() // Now setup the listener *after* attempting to clear any existing session.
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

    func signUp(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        authLogger.info("Creating new account...")
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                authLogger.error("Account creation failed: \(error.localizedDescription)")
                completion(.failure(error))
                return
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
            
            authLogger.info("Account creation successful")
            completion(.success(user))
        }
    }

    func signOut() {
        authLogger.info("[AuthState] signOut() method called.")
        do {
            try Auth.auth().signOut() // This will trigger the listener to update state too

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
        } catch {
            authLogger.error("Error signing out from Firebase: \(error.localizedDescription)")
            // Even if Firebase sign-out fails, attempt to reset local state as a fallback.
            DispatchQueue.main.async {
                self.currentUser = nil
                self.isAuthenticated = false
                self.isAnonymous = false
                self.shouldShowInstructions = true
                // Decide if UserDefaults should be reset here too depending on desired error handling
                // UserDefaults.standard.set(true, forKey: "shouldShowInstructions")
                // UserDefaults.standard.set(false, forKey: "allowAnonymousAccess")
                authLogger.info("[AuthState] Synchronously updated state properties after Firebase signOut error.")
            }
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
}

