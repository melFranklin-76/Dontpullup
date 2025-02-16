import UIKit
import Firebase
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

@objc class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private var firestoreListener: ListenerRegistration?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("AppDelegate: Application launching")
        
        if let user = Auth.auth().currentUser {
            print("Current user ID: \(user.uid)")
        }
        
        return true
    }
    
    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication,
                    configurationForConnecting connectingSceneSession: UISceneSession,
                    options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
    
    func application(_ application: UIApplication,
                    didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Handle discarded scenes if needed
    }
    
    // MARK: - Application Lifecycle
    func applicationWillTerminate(_ application: UIApplication) {
        firestoreListener?.remove()
    }
    
    // MARK: - Firebase URL Handling
    func application(_ application: UIApplication, 
                    open url: URL,
                    options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return true
    }
} 