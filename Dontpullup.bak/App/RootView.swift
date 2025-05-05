import SwiftUI

struct RootView: View {
    @StateObject var authState = AuthState.shared // Observe the shared service instance
    @StateObject private var networkMonitor = NetworkMonitor()
    
    var body: some View {
        Group {
            // Check loading state first
            if authState.isLoading {
                SplashScreen()
            } else {
                // Then check authentication state
                if authState.isAuthenticated {
                    MainTabView()
                       // If MainTabView needs the auth state later, pass it:
                       // .environmentObject(authState)
                } else {
                    AuthView()
                        // Pass the AuthState service to AuthView so it can call signIn/signUp
                        .environmentObject(authState)
                }
            }
        }
        .overlay {
            if !networkMonitor.isConnected {
                VStack {
                    Text("No Internet Connection")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(8)
                }
                .padding(.top, 44) // Adjust padding as needed for UI
            }
        }
        .environmentObject(networkMonitor) // Keep if network monitor is needed down the hierarchy
    }
} 