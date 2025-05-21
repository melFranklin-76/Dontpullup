import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// Firebase module imports
@_exported import Firebase
@_exported import FirebaseCore

// Try different variants of the Firebase modules
#if canImport(FirebaseFirestoreInternal)
@_exported import FirebaseFirestoreInternal
public typealias FirestoreDB = FirebaseFirestoreInternal.Firestore
#else
@_exported import FirebaseFirestore
public typealias FirestoreDB = FirebaseFirestore.Firestore
#endif

#if canImport(FirebaseAuth)
@_exported import FirebaseAuth
#endif

#if canImport(FirebaseStorage)
@_exported import FirebaseStorage
#endif

#if canImport(FirebaseDatabase)
@_exported import FirebaseDatabase
#endif

/// Access the Firestore database in a consistent way regardless of which module is imported
public func getFirestore() -> FirestoreDB {
    return FirestoreDB.firestore()
}

// Helper class to fix import issues
public final class PlatformKit {
    /// Call this in your AppDelegate to ensure all imports are properly loaded
    public static func configure() {
        // This is just to ensure the imports are properly linked
        print("PlatformKit configured")
    }
} 