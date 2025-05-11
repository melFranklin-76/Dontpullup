import UIKit
import SwiftUI
import CoreLocation

// Removed Notification.Name extension - it's now in Utils/NotificationNames.swift

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Comment out the manual window setup to allow SwiftUI App lifecycle to control the root view.
        /*
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: windowScene)
        let rootView = MainTabView()
            .environmentObject(NetworkMonitor())
            .environmentObject(AuthState.shared)
        window?.rootViewController = UIHostingController(rootView: rootView)
        window?.makeKeyAndVisible()
        */
        print("[SceneDelegate] Scene connected. Root view will be set by SwiftUI App lifecycle.")
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Instead of immediately posting notification, use a small delay to ensure
        // all initialization has finished and UI is responsive
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("[SceneDelegate] Scene became active - posting notification for location check")
            NotificationCenter.default.post(name: .appDidBecomeActiveForLocationCheck, object: nil)
        }
    }
} 