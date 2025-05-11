import UIKit
import Firebase
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

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
    
    override init() {
        // Make sure Firebase is already configured from the static initializer
        _ = firebaseLoadTime
        
        super.init()
        
        // Double-check Firebase configuration as a fallback
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("[AppDelegate] Firebase configured in AppDelegate init")
        }
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Final fallback for Firebase configuration
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("[AppDelegate] Firebase configured in didFinishLaunchingWithOptions")
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
