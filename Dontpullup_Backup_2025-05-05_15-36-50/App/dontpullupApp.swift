import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseAnalytics
import AVFoundation
import AVKit
import OSLog
import UIKit

// Logger for the App level if needed
private let appLogger = Logger(subsystem: "com.dontpullup.app", category: "Application")

// Ensure bundle ID is set at the app level
extension Bundle {
    static func setBundleIdentifier() {
        let bundleId = "com.dontpullup.app"
        if Bundle.main.bundleIdentifier == nil {
            // Bundle.main is not optional, we can use it directly
            let bundle = Bundle.main
            objc_setAssociatedObject(bundle, "bundleIdentifier", bundleId, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            // Also set in UserDefaults as backup
            UserDefaults.standard.set(bundleId, forKey: "bundleIdentifier")
            appLogger.info("Bundle identifier manually set to \(bundleId)")
        } else {
            appLogger.info("Bundle identifier already exists: \(Bundle.main.bundleIdentifier ?? "Unknown")")
        }
    }
}

// Presentation coordinator to handle video presentation
class PresentationCoordinator: ObservableObject {
    @Published var isPresenting = false
    @Published var currentPlayerViewController: AVPlayerViewController?
    
    func presentVideo(url: URL, from viewController: UIViewController) {
        guard !isPresenting else { return }
        isPresenting = true
        
        let player = AVPlayer(url: url)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        playerViewController.showsPlaybackControls = true
        playerViewController.entersFullScreenWhenPlaybackBegins = true
        playerViewController.exitsFullScreenWhenPlaybackEnds = true
        currentPlayerViewController = playerViewController
        
        viewController.present(playerViewController, animated: true) {
            player.play()
        }
    }
    
    func dismissCurrentVideo() {
        guard let playerVC = currentPlayerViewController else { return }
        playerVC.player?.pause()
        playerVC.dismiss(animated: true) {
            self.isPresenting = false
            self.currentPlayerViewController = nil
        }
    }
}

@main
struct DontPullUpApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var authState = AuthState.shared
    
    init() {
        appLogger.info("App Initializing...")
        // Set bundle identifier as early as possible
        Bundle.setBundleIdentifier()
        // Firebase is already configured in AppDelegate
        // No need to configure here
        BuildHelper.setupBuildEnvironment()
        print("Build environment setup completed")
    }
    
    var body: some Scene {
        WindowGroup {
            // Use RootView as the main content view
            RootView()
                .preferredColorScheme(.dark) // Apply global scheme
                .environmentObject(networkMonitor) // Inject dependencies
                .environmentObject(authState)
        }
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        print("SceneDelegate: Scene will connect")
        window = UIWindow(windowScene: windowScene)
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        print("SceneDelegate: Scene did disconnect")
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        print("SceneDelegate: Scene did become active")
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        print("SceneDelegate: Scene will resign active")
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        print("SceneDelegate: Scene will enter foreground")
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        print("SceneDelegate: Scene did enter background")
    }
}
