import SwiftUI
import UIKit

/// Determines the root view based on authentication state.
struct RootView: View {
    // Use existing instances instead of creating new ones
    @EnvironmentObject private var authState: AuthState
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    
    // Add more state management
    @State private var isLoading = true
    
    // Add a fixed timeout to ensure app doesn't hang forever
    private let splashTimeout: TimeInterval = 2.0
    
    var body: some View {
        Group {
            if isLoading {
                SplashScreen()
                    .onAppear {
                        // Simple timeout to transition from splash to main app
                        DispatchQueue.main.asyncAfter(deadline: .now() + splashTimeout) {
                            print("Splash screen timeout reached - transitioning to main app")
                            withAnimation {
                                isLoading = false
                            }
                        }
                    }
            } else {
                // Normal app flow
                if authState.isAuthenticated {
                    MainTabView()
                        .transition(.opacity)
                } else {
                    AuthView()
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut, value: isLoading)
        .animation(.easeInOut, value: authState.isAuthenticated)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
        .background(Color.black.ignoresSafeArea())
}

