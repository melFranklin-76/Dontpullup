import SwiftUI
import FirebaseAuth
import Combine

/**
 * User Authentication View Model
 * Acts as an adapter for AuthState to maintain backward compatibility
 */
@MainActor
final class UserAuthViewModel: ObservableObject {
    // Authentication state properties
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    
    // Reference to the central authentication service
    private let authState = AuthState.shared
    
    init() {
        // Forward loading state from AuthState
        authState.$isLoading
            .assign(to: &$isLoading)
        
        // Forward errors from AuthState
        authState.$error
            .compactMap { error -> String? in
                guard let error = error else { return nil }
                return error.localizedDescription
            }
            .sink { [weak self] message in
                guard let self = self else { return }
                self.alertMessage = message
                self.showAlert = true
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Methods
    
    /// Performs anonymous sign in, the primary authentication method
    func signInAnonymously() async throws {
        do {
            try await withCheckedThrowingContinuation { continuation in
                authState.signInAnonymously() { result in
                    switch result {
                    case .success(_):
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            print("User signed in anonymously via UserAuthViewModel")
        } catch {
            alertMessage = "Failed to sign in: \(error.localizedDescription)"
            showAlert = true
            throw error
        }
    }
    
    /// Signs in with email and password
    func signIn(email: String, password: String) async throws {
        do {
            try await withCheckedThrowingContinuation { continuation in
                authState.signIn(email: email, password: password) { result in
                    switch result {
                    case .success(_):
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch {
            alertMessage = "Failed to sign in: \(error.localizedDescription)"
            showAlert = true
            throw error
        }
    }
    
    /// Creates a new user account
    func signUp(email: String, password: String) async throws {
        do {
            try await withCheckedThrowingContinuation { continuation in
                authState.signUp(email: email, password: password) { result in
                    switch result {
                    case .success(_):
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch {
            alertMessage = "Failed to create account: \(error.localizedDescription)"
            showAlert = true
            throw error
        }
    }
    
    /// Signs out the current user
    func signOut() {
        // This method is synchronous and non-throwing based on compiler errors.
        // Assign the returned Bool to _ to silence the "unused result" warning.
        _ = authState.signOut()
    }
}