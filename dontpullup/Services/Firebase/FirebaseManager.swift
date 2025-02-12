import Firebase
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseAnalytics

final class FirebaseManager {
    static let shared = FirebaseManager()
    private var isConfigured = false
    private var db: Firestore?
    
    private init() {}
    
    func configure() {
        guard !isConfigured else { return }
        
        // Initialize Firebase first
        FirebaseApp.configure()
        
        // Configure Firestore settings
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: 100 * 1024 * 1024)) // 100MB cache
        settings.isSSLEnabled = true
        
        // Get Firestore instance and apply settings
        let db = Firestore.firestore()
        db.settings = settings
        self.db = db
        
        // Configure Analytics
        Analytics.setAnalyticsCollectionEnabled(true)
        
        // Enable Firestore debug logging in debug builds only
        #if DEBUG
        Firestore.enableLogging(true)
        #endif
        
        isConfigured = true
        print("Firebase configured successfully")
    }
    
    // Provide access to Firestore instance
    func firestore() -> Firestore {
        guard let db = db else {
            fatalError("Firestore not configured. Call configure() first.")
        }
        return db
    }
} 