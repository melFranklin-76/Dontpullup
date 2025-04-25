import SwiftUI

/// Determines the root view based on authentication state.
struct RootView: View {
    @StateObject private var authState = AuthState.shared
    @StateObject private var networkMonitor = NetworkMonitor()
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                SplashScreen()
                    .environmentObject(authState)
                    .environmentObject(networkMonitor)
                    .onAppear {
                        // Simulate minimum splash screen duration
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                isLoading = false
                            }
                        }
                    }
            } else {
                if authState.isAuthenticated {
                    MainTabView()
                        .environmentObject(authState)
                        .environmentObject(networkMonitor)
                        .transition(.opacity)
                } else {
                    AuthView()
                        .environmentObject(authState)
                        .environmentObject(networkMonitor)
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut, value: isLoading)
        .animation(.easeInOut, value: authState.isAuthenticated)
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
        .background(Color.black.ignoresSafeArea())
}

