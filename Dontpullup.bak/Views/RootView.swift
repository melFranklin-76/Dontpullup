import SwiftUI

struct RootView: View {
    @EnvironmentObject var authState: AuthState // Use the injected AuthState
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    
    var body: some View {
        Group {
            // Check loading state first
            if authState.isLoading {
                SplashScreen()
            } else {
                // Then check authentication state
                if authState.isAuthenticated {
                    MainTabView()
                       // MainTabView will receive authState via environmentObject
                } else {
                    AuthView()
                        // AuthView will receive authState via environmentObject
                }
            }
        }
        .overlay {
            if !networkMonitor.isConnected {
                VStack {
                    Spacer()
                    Text("No Internet Connection")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(8)
                        .padding(.bottom, 20)
                }
            }
        }
    }
} 