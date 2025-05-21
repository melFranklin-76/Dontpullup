import UIKit
import Firebase
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import OSLog

// Create a logger
private let appLogger = Logger(subsystem: "com.dontpullup", category: "AppDelegate")

// Force Firebase initialization at module load time
private let firebaseLoadTime: Void = {
    FirebaseApp.configure()
    print("[AppDelegate] Firebase configured at module load time")
}()

class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    // Static configuration to ensure Firebase is initialized before any other access
    static let shared = AppDelegate()
    
    static var isFirebaseConfigured = true
    
    // Disable Metal validation to prevent debugger interruptions
    private let metalDebugDisabler: Void = {
        UserDefaults.standard.set(false, forKey: "MTL_DEBUG_LAYER")
        setenv("MTL_DEBUG_LAYER", "0", 1)
        setenv("METAL_DEVICE_WRAPPER_TYPE", "0", 1)
        setenv("MTL_DEVICE_DEBUG", "0", 1)
        return ()
    }()
    
    override init() {
        // Make sure Firebase is already configured from the static initializer
        _ = firebaseLoadTime
        
        super.init()
        
        // Double-check Firebase configuration as a fallback
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("[AppDelegate] Firebase configured in AppDelegate init")
        }
        
        // Set up first responder tracking for keyboard management
        setupFirstResponderTracking()
    }
    
    private func setupFirstResponderTracking() {
        // Add notification observers for keyboard tracking
        NotificationCenter.default.addObserver(forName: UITextField.textDidBeginEditingNotification,
                                              object: nil, queue: nil) { notification in
            if let textField = notification.object as? UITextField {
                UIResponder.currentFirstResponder = textField
            }
        }
        
        NotificationCenter.default.addObserver(forName: UITextField.textDidEndEditingNotification,
                                              object: nil, queue: nil) { _ in
            UIResponder.currentFirstResponder = nil
        }
        
        NotificationCenter.default.addObserver(forName: UITextView.textDidBeginEditingNotification,
                                              object: nil, queue: nil) { notification in
            if let textView = notification.object as? UITextView {
                UIResponder.currentFirstResponder = textView
            }
        }
        
        NotificationCenter.default.addObserver(forName: UITextView.textDidEndEditingNotification,
                                              object: nil, queue: nil) { _ in
            UIResponder.currentFirstResponder = nil
        }
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Final fallback for Firebase configuration
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("[AppDelegate] Firebase configured in didFinishLaunchingWithOptions")
        }
        
        // Copy map style resources to accessible location
        DispatchQueue.global(qos: .utility).async {
            // Directly create MapStyles directory since we can't import Utils module here
            let fileManager = FileManager.default
            if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                let mapStylesDirectory = documentsDirectory.appendingPathComponent("MapStyles", isDirectory: true)
                do {
                    if !fileManager.fileExists(atPath: mapStylesDirectory.path) {
                        try fileManager.createDirectory(at: mapStylesDirectory, withIntermediateDirectories: true)
                        print("[AppDelegate] Created MapStyles directory in Documents")
                    }
                } catch {
                    print("[AppDelegate] Error creating MapStyles directory: \(error.localizedDescription)")
                }
            }
        }
        
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Handle discarded scenes if needed
    }
    
    // Add missing required methods for UIApplicationDelegate
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources and save user data
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused while the application was inactive
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate
    }
}
