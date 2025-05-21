import SwiftUI
import FirebaseCore
import FirebaseAuth
import UserNotifications
// import FirebaseCore // Assuming AppDelegate handles this sufficiently

@main
struct DontpullupApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var authState = AuthState.shared
    
    init() {
        print("[DontpullupApp] Initializer started.")
        
        // Configure Metal optimizations and safeguards
        configureMetalSettings()
        
        // Initialize the Metal resource manager to prevent texture deallocation issues
        let _ = MetalResourceManager.shared
        
        print("[DontpullupApp] Initializer finished.")
    }
    
    // Configure Metal settings to prevent issues
    private func configureMetalSettings() {
        // Set Metal environment variables for better error reporting and performance
        setenv("MTL_DEBUG_LAYER", "0", 1)  // Disable Metal debug layer
        setenv("METAL_DEVICE_WRAPPER_TYPE", "1", 1)  // Use Shared mode
        
        // Configure user defaults for Metal
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: "MTLDebugErrorHandler")
        defaults.set(false, forKey: "MTLDebugResourceTracking")
        defaults.synchronize()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authState)
                .environmentObject(networkMonitor)
        }
    }
} 