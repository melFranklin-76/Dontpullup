import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseAnalytics
import AVKit

struct MapStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                // Pre-load map styles to prevent resource warnings
                if let mapStyleURL = Bundle.main.url(forResource: "satellite", withExtension: "json", subdirectory: "MapStyles") {
                    do {
                        let _ = try Data(contentsOf: mapStyleURL)
                    } catch {
                        print("Map style loading error: \(error)")
                    }
                } else {
                    print("Map style file not found in MapStyles directory")
                }
            }
    }
}

extension View {
    func withMapStyle() -> some View {
        modifier(MapStyleModifier())
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
        currentPlayerViewController = playerViewController
        
        viewController.present(playerViewController, animated: true) {
            player.play()
        }
    }
    
    func dismissCurrentVideo() {
        currentPlayerViewController?.dismiss(animated: true) {
            self.isPresenting = false
            self.currentPlayerViewController = nil
        }
    }
}

@main
struct DontPullUpApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var authState = AuthState()
    
    init() {
        // Configure Firebase first
        FirebaseManager.shared.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                Group {
                    if !authState.isInitialized {
                        // Show loading view while auth state is being determined
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else if authState.isSignedIn {
                        ContentView()
                            .preferredColorScheme(.dark)
                            .environmentObject(networkMonitor)
                            .withMapStyle()
                    } else {
                        AuthView()
                            .preferredColorScheme(.dark)
                            .environmentObject(networkMonitor)
                    }
                }
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    var window: UIWindow?
    private var firestoreListener: ListenerRegistration?
    
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("AppDelegate: Application launching")
        
        if let user = Auth.auth().currentUser {
            print("Current user ID: \(user.uid)")
        }
        
        return true
    }
    
    func application(_ application: UIApplication,
                    configurationForConnecting connectingSceneSession: UISceneSession,
                    options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        sceneConfig.delegateClass = SceneDelegate.self
        return sceneConfig
    }
    
    func application(_ application: UIApplication,
                    didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        firestoreListener?.remove()
    }
    
    // Required for Firebase Analytics
    func application(_ application: UIApplication, open url: URL,
                    options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return true
    }
    
    // Required for Firebase Push Notifications
    func application(_ application: UIApplication,
                    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    }
    
    func application(_ application: UIApplication,
                    didFailToRegisterForRemoteNotificationsWithError error: Error) {
    }
    
    func application(_ application: UIApplication,
                    didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        completionHandler(.noData)
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
