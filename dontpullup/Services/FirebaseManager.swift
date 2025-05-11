import Firebase
import FirebaseFirestore

// Make this public to avoid redeclaration issues
public final class FirebaseManager {
    public static let shared = FirebaseManager()
    private let db: Firestore
    
    private init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        self.db = Firestore.firestore()
    }
    
    public func firestore() -> Firestore { db }
}
