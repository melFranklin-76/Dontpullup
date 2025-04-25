import SwiftUI
import FirebaseAuth

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isShowingSignIn = false
    @Published var isShowingSignUp = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func signInAnonymously() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await Auth.auth().signInAnonymously()
            print("Signed in anonymously with user: \(result.user.uid)")
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func signOut() throws {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
} 