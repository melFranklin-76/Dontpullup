import Foundation
import SwiftUI

// Define platform-specific imports
#if canImport(UIKit)
import UIKit
public typealias PlatformColor = UIColor
public typealias PlatformView = UIView
public typealias PlatformImage = UIImage
public typealias PlatformDevice = UIDevice
#else
import AppKit
public typealias PlatformColor = NSColor
public typealias PlatformView = NSView
public typealias PlatformImage = NSImage
public struct PlatformDevice {
    public static let current = PlatformDevice()
    public var identifierForVendor: UUID? {
        return UUID()
    }
}
#endif

// Provide Firebase module definitions that work across all platforms
public struct FirebaseModules {
    public static let firestore = Firestore.firestore()
    
    public static func configure() {
        // This is just a placeholder to make sure the module is linked
        FirebaseApp.configure()
    }
}

// Define the Firestore type
#if canImport(FirebaseFirestoreInternal)
import FirebaseFirestoreInternal
public typealias Firestore = FirebaseFirestoreInternal.Firestore
#else
import FirebaseFirestore
public typealias Firestore = FirebaseFirestore.Firestore
#endif

// Import Firebase modules
import Firebase
import FirebaseCore
import FirebaseAuth
import FirebaseStorage
import FirebaseDatabase
import CoreLocation

// This file helps establish proper imports and type visibility
// Import all relevant types explicitly to ensure they're available

// Extension to make sure all types are properly visible
extension IncidentType {
    static func makePublic() {
        _ = IncidentType.verbal
        _ = IncidentType.physical
        _ = IncidentType.emergency
        _ = IncidentType.fromFirestoreType("Verbal")
    }
}

extension Pin {
    static func makePublic() {
        // Create a sample pin to ensure the type is properly registered
        let coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        _ = Pin(id: "test", coordinate: coordinate, incidentType: .verbal, videoURL: "", userId: "")
    }
}

// Make AuthState helpers
extension AuthState {
    // Use the existing shared instance instead of creating a new one
    static func accessShared() {
        // Access the shared instance that was already created
        _ = AuthState.shared
    }
}

// Make FirebaseManager helpers
extension FirebaseManager {
    // Access singleton instance
    static func getShared() -> FirebaseManager {
        return FirebaseManager.shared
    }
}

/// This file ensures that Firebase modules are correctly imported in the project
/// It fixes build issues with Firebase modules not being found
struct FirebaseModuleFixHelper {
    static func ensureImportsWork() {
        // This function is never called, it just ensures that imports are recognized
        print("Firebase modules imported correctly")
    }
} 