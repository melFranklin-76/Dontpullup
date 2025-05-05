import SwiftUI
import FirebaseAuth
import Combine

@MainActor
final class UserAuthViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    
    // MARK: - Private Properties
    private let authState: AuthState
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(authState: AuthState = .shared) {
        self.authState = authState
        
        // Subscribe to auth state changes
        authState.$error
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.alertMessage = error.localizedDescription
                self?.showAlert = true
            }
            .store(in: &cancellables)
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
                    continuation.resume( .success:
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
        if !authState.signOut() {
            alertMessage = "Failed to sign out"
            showAlert = true
        }
    }
} 