import Foundation
import FirebaseAuth

/**
 The AuthState class is responsible for managing the authentication state of the user.
 It listens for changes in the authentication state and updates the isSignedIn property accordingly.
 */
class AuthState: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var isInitialized: Bool = false
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        setupAuthStateListener()
    }
    
    /**
     Sets up a listener for changes in the authentication state.
     Updates the isSignedIn property based on the authentication state.
     */
    private func setupAuthStateListener() {
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            self.isSignedIn = (user != nil)
            self.isInitialized = true
        }
    }
    
    /**
     Removes the authentication state listener when the AuthState instance is deinitialized.
     */
    deinit {
        if let handle = authStateListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
