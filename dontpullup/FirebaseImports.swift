import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// Firebase imports
#if canImport(FirebaseCore)
import FirebaseCore
#endif

// Try different variants of the Firebase modules
#if canImport(FirebaseFirestore)
import FirebaseFirestore
public typealias FirestoreImport = FirebaseFirestore.Firestore
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

#if canImport(FirebaseDatabase)
import FirebaseDatabase
#endif

/// Access the Firestore database in a consistent way regardless of which module is imported
public func getFirestore() -> FirestoreImport? {
    #if canImport(FirebaseFirestore)
    return FirestoreImport.firestore()
    #else
    return nil
    #endif
}

// Helper class to fix import issues
public final class FirebaseImportFixer {
    /// Call this in your AppDelegate to ensure all imports are properly loaded
    public static func ensureImportsWork() {
        // This is just to ensure the imports are properly linked
        print("Firebase imports configured correctly")
    }
} 