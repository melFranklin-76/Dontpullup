import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
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