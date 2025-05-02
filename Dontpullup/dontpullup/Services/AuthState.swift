import Foundation
import FirebaseAuth
import Combine
import SwiftUI
import FirebaseFirestore
import FirebaseStorage

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
    
    /// Deletes the current user account and all associated data
    public func deleteAccount() async -> Result<Void, Error> {
        guard let user = Auth.auth().currentUser else {
            return .failure(NSError(domain: "AuthState", code: -1, 
                                   userInfo: [NSLocalizedDescriptionKey: "No user is currently signed in"]))
        }
        
        do {
            // 1. Delete user's pins from Firestore
            let db = FirebaseManager.shared.firestore()
            let userPins = try await db.collection("pins")
                .whereField("userID", isEqualTo: user.uid)
                .getDocuments()
                .documents
            
            // 2. Delete all user pins and associated videos
            for pinDoc in userPins {
                // 3. If there's a video URL, delete from Storage too
                if let videoURL = pinDoc.data()["videoURL"] as? String,
                   let storageURL = URL(string: videoURL) {
                    do {
                        let storageRef = Storage.storage().reference(forURL: storageURL.absoluteString)
                        try await storageRef.delete()
                    } catch {
                        print("Warning: Could not delete video: \(error.localizedDescription)")
                        // Continue deleting other content
                    }
                }
                
                // Delete the pin document
                try await db.collection("pins").document(pinDoc.documentID).delete()
            }
            
            // 4. Delete user reports if any
            let userReports = try await db.collection("reports")
                .whereField("reportedBy", isEqualTo: user.uid)
                .getDocuments()
                .documents
            
            for reportDoc in userReports {
                try await db.collection("reports").document(reportDoc.documentID).delete()
            }
            
            // 5. Finally delete the user account itself
            try await user.delete()
            
            // 6. Update auth state
            // Capture values locally to avoid Sendable issues with self capture
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUser = nil
                self.error = nil
            }
            
            return .success(())
            
        } catch {
            return .failure(error)
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