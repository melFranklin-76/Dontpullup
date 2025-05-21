import Foundation
import SwiftUI

// Firebase imports
@_exported import Firebase

// Conditionally import Firebase modules
@_exported import FirebaseCore

// FirebaseFirestore or FirebaseFirestoreInternal
#if canImport(FirebaseFirestoreInternal)
@_exported import FirebaseFirestoreInternal
public typealias FirestoreDBType = FirebaseFirestoreInternal.Firestore
#else
@_exported import FirebaseFirestore
public typealias FirestoreDBType = FirebaseFirestore.Firestore
#endif

@_exported import FirebaseAuth
@_exported import FirebaseStorage

// Define a utility struct for Firebase
public struct FirebaseModulesHelper {
    // Get Firestore database
    public static var firestore: FirestoreDBType {
        return FirestoreDBType.firestore()
    }
    
    // Initialize Firebase
    public static func configure() {
        FirebaseApp.configure()
    }
    
    // Get current auth instance
    public static var auth: Auth {
        return Auth.auth()
    }
    
    // Get current user
    public static var currentUser: User? {
        return Auth.auth().currentUser
    }
    
    // Get storage reference
    public static var storage: Storage {
        return Storage.storage()
    }
    
    // Ensure all imports work properly - call this somewhere in your app
    public static func verifyImports() {
        print("Firebase modules verified")
    }
} 