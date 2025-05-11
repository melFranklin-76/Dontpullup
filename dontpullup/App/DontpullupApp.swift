import SwiftUI
import FirebaseCore

@main
struct DontpullupApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var networkMonitor = NetworkMonitor()
    private var authState = AuthState.shared // Access the shared instance
    
    init() {
        FirebaseApp.configure() // Configure Firebase
        // Firebase is now configured in AppDelegate
        print("[DontpullupApp] Application initializer - Firebase explicitly configured here.")
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(networkMonitor) // Inject NetworkMonitor
                .environmentObject(authState)    // Inject AuthState
        }
    }
} 