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
        
        do {
            try await authState.signInAnonymouslyAsync()
        } catch {
            showAlert = true
            alertMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Signs in with email and password
    func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            _ = try await authState.signInAsync(email: email, password: password)
        } catch {
            showAlert = true
            alertMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Signs up with email, password, and zip code
    func signUp(email: String, password: String, zipCode: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            _ = try await authState.signUpAsync(email: email, password: password, zipCode: zipCode)
        } catch {
            showAlert = true
            alertMessage = error.localizedDescription
            throw error
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