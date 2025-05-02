import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseAnalytics
import AVFoundation
import AVKit
import OSLog
import ObjectiveC

// Logger for the App level if needed
private let appLogger = Logger(subsystem: "com.dontpullup.app", category: "Application")

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
    @State private var hasInitialized = false
    
    init() {
        appLogger.info("App Initializing...")
        
        // Setup any crash handlers or error trackers
        setupErrorHandling()
    }
    
    var body: some Scene {
        WindowGroup {
            // Use RootView as the main content view
            RootView()
                .preferredColorScheme(.dark) // Apply global scheme
                .environmentObject(networkMonitor) // Inject dependencies
                .environmentObject(authState)
                .background(Color.black.ignoresSafeArea()) // Apply global background
                .onAppear {
                    // Do any one-time initialization when the app appears
                    if !hasInitialized {
                        performFirstTimeInitialization()
                        hasInitialized = true
                    }
                }
        }
    }
    
    // Helper method for error handling setup
    private func setupErrorHandling() {
        // Set up any global error handlers here
        
        // Example: Handle uncaught exceptions
        NSSetUncaughtExceptionHandler { exception in
            appLogger.error("CRASH: Uncaught exception: \(exception.name.rawValue) - \(exception.reason ?? "no reason") \(exception.callStackSymbols.joined(separator: "\n"))")
        }
    }
    
    // One-time initialization tasks
    private func performFirstTimeInitialization() {
        appLogger.info("Performing first-time initialization tasks")
        
        // Add any app-wide initialization that should happen once
        // For example, configure libraries or services
        
        // Monitor and log app lifecycle
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            appLogger.info("App became active")
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            appLogger.info("App will resign active")
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
        
        // Apply the keyboard constraint fix globally
        UIViewController.swizzleViewDidLoad()
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
        
        // Force refresh Firebase auth token when coming back to foreground
        if let user = Auth.auth().currentUser {
            user.getIDTokenForcingRefresh(true) { _, error in
                if let error = error {
                    print("Error refreshing Firebase token: \(error.localizedDescription)")
                } else {
                    print("Successfully refreshed Firebase auth token")
                }
            }
        }
        
        // Ensure network connectivity is properly reestablished
        NotificationCenter.default.post(name: NSNotification.Name("AppWillEnterForeground"), object: nil)
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        print("SceneDelegate: Scene did enter background")
    }
}

// Extend UIViewController with method swizzling to apply keyboard constraints fix
extension UIViewController {
    static var swizzleViewDidLoadOnce: Bool = false
    
    static func swizzleViewDidLoad() {
        guard !swizzleViewDidLoadOnce else { return }
        swizzleViewDidLoadOnce = true
        
        let originalSelector = #selector(UIViewController.viewDidLoad)
        let swizzledSelector = #selector(UIViewController.swizzled_viewDidLoad)
        
        guard let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector) else {
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
    
    @objc func swizzled_viewDidLoad() {
        // Call original viewDidLoad
        self.swizzled_viewDidLoad()
        
        // Apply keyboard constraint fix
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
                    // Fix assistant height constraint
                    DispatchQueue.main.async {
                        keyWindow.subviews.forEach { view in
                            Self.findAndFixAssistantHeightConstraint(in: view)
                        }
                    }
                }
            }
        }
    }
    
    private static func findAndFixAssistantHeightConstraint(in view: UIView) {
        // Check if the view has a class name containing "SystemInputAssistantView"
        let viewTypeName = String(describing: type(of: view))
        if viewTypeName.contains("SystemInputAssistantView") {
            // Remove height constraint with identifier "assistantHeight"
            for constraint in view.constraints where constraint.identifier == "assistantHeight" {
                constraint.isActive = false
                print("Fixed keyboard input assistant constraint")
                break
            }
        }
        
        // Continue searching in subviews
        for subview in view.subviews {
            findAndFixAssistantHeightConstraint(in: subview)
        }
    }
}
