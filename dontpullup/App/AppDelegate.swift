import UIKit
import Firebase
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

/**
 The AppDelegate class is responsible for handling application-level events and configurations.
 It conforms to the UIApplicationDelegate protocol.
 */
@main
class AppDelegate: NSObject, UIApplicationDelegate {
    
    /**
     This method is called when the application has finished launching.
     It is used to perform any final initialization before the app is presented to the user.
     
     - Parameters:
        - application: The singleton app object.
        - launchOptions: A dictionary indicating the reason the app was launched (if any).
     
     - Returns: A boolean value indicating whether the app successfully handled the launch.
     */
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("AppDelegate: Application launching")
        
        // Configure Firebase
        FirebaseApp.configure()
        
        return true
    }
    
    /**
     This method is called when a new scene session is being created.
     It is used to select a configuration to create the new scene with.
     
     - Parameters:
        - application: The singleton app object.
        - connectingSceneSession: The session being created.
        - options: Additional options for configuring the scene.
     
     - Returns: A UISceneConfiguration object containing the configuration data for the new scene.
     */
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
    
    /**
     This method is called when the user discards a scene session.
     It is used to release any resources that were specific to the discarded scenes.
     
     - Parameters:
        - application: The singleton app object.
        - sceneSessions: The set of discarded scene sessions.
     */
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Handle discarded scenes if needed
    }
}
