import SwiftUI
import FirebaseAuth

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    
    func signInAnonymously() async throws {
        isLoading = true
        defer { isLoading = false }
        
        let result = try await Auth.auth().signInAnonymously()
        print("User signed in with ID: \(result.user.uid)")
    }
} 