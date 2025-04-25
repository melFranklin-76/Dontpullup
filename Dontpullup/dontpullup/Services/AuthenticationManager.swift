@preconcurrency import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
final class AuthenticationManager: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    
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
                print("AuthenticationManager: Auth state changed - User: \(user?.uid ?? "none")")
            }
        }
    }
    
    func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        self.currentUser = result.user
        self.isAuthenticated = true
        self.errorMessage = nil
        print("AuthenticationManager: Sign in successful - User: \(result.user.uid)")
    }
    
    func signUp(email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        self.currentUser = result.user
        self.isAuthenticated = true
        self.errorMessage = nil
        print("AuthenticationManager: Sign up successful - User: \(result.user.uid)")
        
        // Create user document in Firestore
        try await createUserProfile(for: result.user)
    }
    
    func signInAnonymously() async throws {
        let result = try await Auth.auth().signInAnonymously()
        self.currentUser = result.user
        self.isAuthenticated = true
        self.errorMessage = nil
        print("AuthenticationManager: Anonymous sign in successful - User: \(result.user.uid)")
        
        // Create anonymous user profile
        try await createUserProfile(for: result.user)
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
        self.currentUser = nil
        self.isAuthenticated = false
        self.errorMessage = nil
        print("AuthenticationManager: Sign out successful")
    }
    
    private func createUserProfile(for user: User) async throws {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)
        
        let userData: [String: Any] = [
            "uid": user.uid,
            "email": user.email ?? "",
            "isAnonymous": user.isAnonymous,
            "createdAt": FieldValue.serverTimestamp(),
            "lastLogin": FieldValue.serverTimestamp()
        ]
        
        try await userRef.setData(userData, merge: true)
        print("AuthenticationManager: User profile created in Firestore - User: \(user.uid)")
    }
    
    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
