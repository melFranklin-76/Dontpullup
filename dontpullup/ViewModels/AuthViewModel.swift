import SwiftUI
import FirebaseManager

/**
 The AuthViewModel class is responsible for managing the authentication process.
 It provides methods for signing in anonymously and handles the loading state and alert messages.
 */
@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    
    /**
     Signs in the user anonymously using Firebase Authentication.
     Updates the isLoading property to indicate the loading state.
     If the sign-in is successful, prints the user ID to the console.
     If an error occurs, throws the error.
     
     - Throws: An error if the sign-in process fails.
     */
    func signInAnonymously() async throws {
        isLoading = true
        defer { isLoading = false }
        
        let result = try await Auth.auth().signInAnonymously()
        print("User signed in with ID: \(result.user.uid)")
    }
}
