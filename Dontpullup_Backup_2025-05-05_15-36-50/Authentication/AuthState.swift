import FirebaseAuth
import SwiftUI
import OSLog

private let authLogger = Logger(subsystem: "com.dontpullup.app", category: "Authentication")

class AuthState: ObservableObject {
    // Singleton pattern
    static let shared = AuthState()
    
    // Published properties
    @Published var isAuthenticated: Bool = false
    @Published var isInitialized: Bool = false
    @Published var isLoading: Bool = true
    @Published var currentUser: User?
    
    private var handle: AuthStateDidChangeListenerHandle?
    
    private init() {
        authLogger.info("Initializing authentication state observer")
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
                self.isAuthenticated = user != nil
                
                if let user = user {
                    authLogger.info("User signed in - ID: \(user.uid)")
                    if let email = user.email {
                        authLogger.info("User email: \(email)")
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
                }
            }
        }
    }
    
    var isSignedIn: Bool {
        return isAuthenticated
    }
    
    // Authentication methods
    func signInAnonymously() async throws {
        authLogger.info("Starting anonymous authentication...")
        try await Auth.auth().signInAnonymously()
        authLogger.info("Anonymous authentication successful")
    }

                            _ = try await user.getIDToken(forcingRefresh: true)
                        } catch {
                            authLogger.error("Failed to refresh user token: \(error.localizedDescription)")
                        }
                    }
                } else {
                    authLogger.info("User signed out")
                }
            }
        }
    }
    
    var isSignedIn: Bool {
        return isAuthenticated
    }
    
    // Authentication methods
    func signInAnonymously() async throws {
        authLogger.info("Starting anonymous authentication...")
        try await Auth.auth().signInAnonymously()
        authLogger.info("Anonymous authentication successful")
    }

    func signIn(email: String, password: String) async throws {
        authLogger.info("Signing in with email...")
        try await Auth.auth().signIn(withEmail: email, password: password)
        authLogger.info("Email sign-in successful")
    }

    func signUp(email: String, password: String) async throws {
        authLogger.info("Creating new account...")
        try await Auth.auth().createUser(withEmail: email, password: password)
        authLogger.info("Account creation successful")
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            authLogger.error("Error signing out: \(error.localizedDescription)")
        }
    }
    
    deinit {
        if let handle = handle {
            authLogger.info("Removing auth state listener")
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}

