import FirebaseAuth
import SwiftUI

class AuthState: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var isInitialized: Bool = false
    private var handle: AuthStateDidChangeListenerHandle?
    
    init() {
        print("AuthState: Initializing authentication state observer")
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
                    print("AuthState: Initial state received")
                }
                
                self.isSignedIn = user != nil
                if let user = user {
                    print("AuthState: User signed in - ID: \(user.uid)")
                    if let email = user.email {
                        print("AuthState: User email: \(email)")
                    }
                    
                    // Refresh the user's token to ensure it's valid
                    Task {
                        do {
                            _ = try await user.getIDToken(forcingRefresh: true)
                        } catch {
                            print("AuthState: Failed to refresh user token: \(error)")
                        }
                    }
                } else {
                    print("AuthState: User signed out")
                }
            }
        }
    }
    
    deinit {
        if let handle = handle {
            print("AuthState: Removing auth state listener")
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
} 