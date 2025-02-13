import SwiftUI
import AVKit

/**
 The DontPullUpApp struct is the main entry point of the application.
 It conforms to the App protocol and is responsible for setting up the initial state and UI of the app.
 */
@main
struct DontPullUpApp: App {
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var authState = AuthState()
    
    init() {
        // Configure Firebase first
        do {
            try FirebaseManager.shared.configure()
        } catch {
            print("Firebase configuration error: \(error)")
        }
    }
    
    /**
     The body property defines the content and behavior of the app's main scene.
     It uses a ZStack to layer the UI components and conditionally displays different views based on the authentication state.
     */
    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                Group {
                    if !authState.isInitialized {
                        // Show loading view while auth state is being determined
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else if authState.isSignedIn {
                        ContentView()
                            .preferredColorScheme(.dark)
                            .environmentObject(networkMonitor)
                            .withMapStyle()
                    } else {
                        AuthView()
                            .preferredColorScheme(.dark)
                            .environmentObject(networkMonitor)
                    }
                }
            }
        }
    }
}
