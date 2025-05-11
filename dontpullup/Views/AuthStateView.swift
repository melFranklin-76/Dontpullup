import SwiftUI

struct AuthStateView: View {
    @StateObject private var viewModel = UserAuthViewModel()
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Signing in...")
            } else {
                Text("Welcome to Don't Pull Up")
                    .font(.title)
                    .padding()
                
                Button("Continue as Guest") {
                    Task {
                        do {
                            try await viewModel.signInAnonymously()
                        } catch {
                            // Error is already handled by the view model
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .alert("Error", isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
    }
} 