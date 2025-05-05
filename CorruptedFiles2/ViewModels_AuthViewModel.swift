import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var showDeleteAccountConfirmation = false
    @Published var deleteAccountPassword = ""
    
    func signInAnonymously() async throws {
        isLoading = true
        defer { isLoading = false }
        
        let result = try await Auth.auth().signInAnonymously()
        print("User signed in with ID: \(result.user.uid)")
    }
    
    func deleteAccount(password: String? = nil) async throws {
        isLoading = true
        defer { isLoading = false }
        
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user is currently signed in"])
        }
        
        // For anonymous users, we can delete directly
        if user.isAnonymous {
            try await deleteUserData(for: user.uid)
            try await user.delete()
            return
        }
        
        // For email users, we need to reauthenticate first
        guard let password = password, !password.isEmpty else {
            throw NSError(domain: "AuthError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Password is required to delete account"])
        }
        
        guard let email = user.email else {
            throw NSError(domain: "AuthError", code: -3, userInfo: [NSLocalizedDescriptionKey: "User email not found"])
        }
        
        // Create credential and reauthenticate
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        try await user.reauthenticate(with: credential)
        
        // Delete user data from Firestore
        try await deleteUserData(for: user.uid)
        
        // Delete the user account
        try await user.delete()
    }
    
    private func deleteUserData(for userId: String) async throws {
        // Delete user's pins from Firestore
        let db = Firestore.firestore()
        let pinsQuery = db.collection("pins").whereField("userID", isEqualTo: userId)
        
        let snapshot = try await pinsQuery.getDocuments()
        for document in snapshot.documents {
            try await db.collection("pins.reauthenticate(with: credential)
        
        // Delete user data from Firestore
        try await deleteUserData(for: user.uid)
        
        // Delete the user account
        try await user.delete()
    }
    
    private func deleteUserData(for userId: String) async throws {
        // Delete user's pins from Firestore
        let db = Firestore.firestore()
        let pinsQuery = db.collection("pins").whereField("userID", isEqualTo: userId)
        
        let snapshot = try await pinsQuery.getDocuments()
        for document in snapshot.documents {
            try await db.collection("pins").document(document.documentID).delete()
        }
        
        // Note: Additional user data deletion should be added here if needed
    }
}
