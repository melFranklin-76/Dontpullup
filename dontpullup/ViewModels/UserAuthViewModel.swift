import SwiftUI
import FirebaseAuth

@MainActor
final class UserAuthViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    
    // MARK: - Private Properties
    private let authState: AuthState
    
    // MARK: - Initialization
    init(authState: AuthState = .shared) {
        self.authState = authState
    }
    
    // MARK: - Public Methods
    
    /// Signs in anonymously using the AuthState service
    func signInAnonymously() async throws {
        isLoading = true
        defer { isLoading = false }
        
        return try await withCheckedThrowingContinuation { continuation in
            authState.signInAnonymously { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Signs in with email and password
    func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        return try await withCheckedThrowingContinuation { continuation in
            authState.signIn(email: email, password: password) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Signs up with email and password
    func signUp(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        return try await withCheckedThrowingContinuation { continuation in
            authState.signUp(email: email, password: password) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Signs out the current user
    func signOut() {
        authState.signOut()
    }
    
    /// Checks if the current user is anonymous
    var isAnonymous: Bool {
        return authState.isAnonymous
    }
    
    /// Checks if the current user is registered (non-anonymous)
    var isRegisteredUser: Bool {
        return authState.isRegisteredUser
    }
} 