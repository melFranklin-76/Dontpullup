import UIKit
import Firebase
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("AppDelegate: Application launching")
        
        // Configure Firebase
        FirebaseApp.configure()
        
        // Removed placeholder syncWithRootFolder() call – unnecessary for production and caused runtime errors when the hard‑coded path didn’t exist.
        
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
    
    // Placeholder syncWithRootFolder() removed – handled by asset catalogs and Xcode build phases.
}
