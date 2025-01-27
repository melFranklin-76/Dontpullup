import SwiftUI
import Firebase
import FirebaseAuth
import Network
import FirebaseCore
import FirebaseFirestore

struct MapStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                // Pre-load map styles to prevent resource warnings
                if let mapStyleURL = Bundle.main.url(forResource: "satellite", withExtension: "json") {
                    do {
                        let _ = try Data(contentsOf: mapStyleURL)
                    } catch {
                        print("Map style loading error: \(error)")
                    }
                }
            }
    }
}

extension View {
    func withMapStyle() -> some View {
        modifier(MapStyleModifier())
    }
}

@main
struct DontPullUpApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var authState: AuthState
    
    init() {
        // Initialize auth state
        _authState = StateObject(wrappedValue: AuthState())
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
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        print("AppDelegate: Application launching")
        
        // Configure Firebase first
        FirebaseApp.configure()
        
        // Configure Firestore settings
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
        let db = Firestore.firestore()
        db.settings = settings
        
        // Setup connectivity monitoring
        setupFirestoreConnectivityMonitoring()
        
        return true
    }
    
    func application(_ application: UIApplication,
                    configurationForConnecting connectingSceneSession: UISceneSession,
                    options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let sceneConfig = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        sceneConfig.delegateClass = SceneDelegate.self
        return sceneConfig
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Clean up any resources
        firestoreListener?.remove()
    }
    
    private func setupFirestoreConnectivityMonitoring() {
        firestoreListener = Firestore.firestore().collection("connectivity")
            .document("status")
            .addSnapshotListener { (_, error) in
                if let error = error {
                    if (error as NSError).domain == "FIRFirestoreErrorDomain" {
                        NotificationCenter.default.post(
                            name: Notification.Name("FirestoreConnectionStatus"),
                            object: nil,
                            userInfo: ["isConnected": false]
                        )
                        print("Firestore connection lost: \(error.localizedDescription)")
                    }
                } else {
                    NotificationCenter.default.post(
                        name: Notification.Name("FirestoreConnectionStatus"),
                        object: nil,
                        userInfo: ["isConnected": true]
                    )
                    print("Firestore connection established")
                }
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

class AuthState: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var isInitialized: Bool = false
    private var handle: AuthStateDidChangeListenerHandle?
    
    init() {
        print("AuthState: Initializing authentication state observer")
        handle = Auth.auth().addStateDidChangeListener { [weak self] (auth: Auth, user: User?) in
            guard let self = self else { return }
            
            if !self.isInitialized {
                self.isInitialized = true
                print("AuthState: Initial state received")
            }
            
            self.isSignedIn = user != nil
            if let user = user {
                print("AuthState: User signed in - ID: \(user.uid)")
                if let email = user.email {
                    print("AuthState: User email: \(email)")
                }
            } else {
                print("AuthState: User signed out")
            }
        }
    }
    
    deinit {
        if let handle = handle {
            print("AuthState: Removing auth state listener")
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
