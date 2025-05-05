import Foundation
import FirebaseAuth
import Combine
import SwiftUI

/// Central authentication service that manages all Firebase Auth interactions
public final class AuthState: ObservableObject {
    // Static shared instance
    public static let shared = AuthState()
    
    // MARK: - Published Properties
    @Published public var isAuthenticated: Bool = false
    @Published public var currentUser: User?
    @Published public var isLoading: Bool = true
    @Published public var error: Error?
    
    // MARK: - Private Properties
    private var stateListener: AuthStateDidChangeListenerHandle?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let listener = stateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Public Methods
    /// Signs in with email and password
    public func signIn(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        isLoading = true
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.error = error
                    completion(.failure(error))
                    return
                }
                
                if let user = authResult?.user {
                    self.currentUser = user
                    self.isAuthenticated = true
                    completion(.success(user))
                }
            }
        }
    }
    
    /// Signs up with email and password
    public func signUp(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        isLoading = true
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.error = error
                    completion(.failure(error))
                    return
                }
                
                if let user = authResult?.user {
                    self.currentUser = user
                    self.isAuthenticated = true
                    completion(.success(user))
                }
            }
        }
    }
    
    /// Signs in anonymously
    public func signInAnonymously(completion: @escaping (Result<User, Error>) -> Void) {
        isLoading = true
        
        Auth.auth().signInAnonymously { [weak self] authResult, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.error = error
                    completion(.failure(error))
                    return
                }
                
                if let user = authResult?.user {
                    self.currentUser = user
                    self.isAuthenticated = true
                    completion(.success(user))
                }
            }
        }
    }
    
    /// Signs out the current user
    public func signOut() -> Bool {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
            currentUser = nil
            error = nil
            return true
        } catch {
            self.error = error
            return false
        }
    }
    
    // MARK: - Private Methods
    private func setupAuthStateListener() {
        stateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                self.currentUser = user
                self.isAuthenticated = user != nil
            }
        }
    }
} 