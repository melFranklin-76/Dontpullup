import Firebase
import FirebaseFirestore

/**
 The FirebaseManager class is responsible for managing the Firebase configuration and Firestore instance.
 */
class FirebaseManager {
    static let shared = FirebaseManager()
    private var firestoreInstance: Firestore?
    private var cache = NSCache<NSString, DocumentSnapshot>()
    
    private init() {}
    
    /**
     Configures the Firebase app. This method should be called once during the app's initialization.
     */
    func configure() {
        do {
            try FirebaseApp.configure()
        } catch {
            print("Error configuring Firebase: \(error.localizedDescription)")
        }
    }
    
    /**
     Returns the Firestore instance. If the instance is not already initialized, it initializes it first.
     
     - Returns: The Firestore instance.
     */
    func firestore() -> Firestore {
        if firestoreInstance == nil {
            firestoreInstance = Firestore.firestore()
        }
        return firestoreInstance!
    }
    
    /**
     Fetches a Firestore document, checking the cache first before making a network request.
     
     - Parameters:
        - collection: The name of the Firestore collection.
        - document: The name of the Firestore document.
        - completion: A closure to be called with the fetched document or an error.
     */
    func fetchDocument(collection: String, document: String, completion: @escaping (DocumentSnapshot?, Error?) -> Void) {
        let cacheKey = "\(collection)/\(document)" as NSString
        
        if let cachedDocument = cache.object(forKey: cacheKey) {
            print("Loaded document from cache")
            completion(cachedDocument, nil)
        } else {
            firestore().collection(collection).document(document).getDocument { [weak self] snapshot, error in
                if let snapshot = snapshot {
                    self?.cache.setObject(snapshot, forKey: cacheKey)
                    print("Document loaded and cached")
                }
                completion(snapshot, error)
            }
        }
    }
}
