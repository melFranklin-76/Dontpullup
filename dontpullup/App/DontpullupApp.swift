import SwiftUI
import FirebaseCore
// import FirebaseCore // Assuming AppDelegate handles this sufficiently

@main
struct DontpullupApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var authState: AuthState // Declare as @StateObject, initialize in init
    
    init() {
        // Firebase should already be configured by the module load-time initializer
        // No need to reference AppDelegate.configureFirebase anymore
        
        // Initialize AuthState
        self._authState = StateObject(wrappedValue: AuthState.shared)
        print("[DontpullupApp] Initializer finished.")
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(networkMonitor) // Inject NetworkMonitor
                .environmentObject(authState)    // Inject AuthState
        }
    }
} 