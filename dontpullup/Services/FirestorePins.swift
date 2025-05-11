import Foundation
import FirebaseFirestore
import CoreLocation
import FirebaseAuth
import UIKit

/// Utility class for Firestore pin operations
enum FirestorePins {
    
    private static let db = Firestore.firestore()
    
    /// Adds a pin to Firestore
    /// - Parameters:
    ///   - id: The pin ID
    ///   - coord: The coordinates of the pin
    ///   - type: The incident type
    ///   - videoURL: The remote video URL (if any)
    /// - Throws: Error if the operation fails
    static func addPin(id: String, coord: CLLocationCoordinate2D, type: IncidentType, videoURL: String) async throws {
        // Accessing Auth and UIDevice is MainActor-isolated in recent SDKs, so grab
        // those values explicitly on the main thread to avoid the
        // "Expression is 'async' but is not marked with 'await'" error.
        let uid: String = await MainActor.run {
            Auth.auth().currentUser?.uid ?? ""
        }
        let deviceID: String = await MainActor.run {
            UIDevice.current.identifierForVendor?.uuidString ?? ""
        }
        
        let data: [String: Any] = [
            "latitude": coord.latitude,
            "longitude": coord.longitude,
            "type": type.firestoreType, // Ensures we use Verbal, Physical, 911
            "videoURL": videoURL,
            "userId": uid,
            "timestamp": Timestamp(),
            "deviceID": deviceID
        ]
        
        try await db.collection("pins").document(id).setData(data)
    }
    
    /// Deletes a pin from Firestore
    /// - Parameter id: The ID of the pin to delete
    /// - Throws: Error if the operation fails
    static func deletePin(id: String) async throws {
        try await db.collection("pins").document(id).delete()
    }
    
    /// Retrieves all pins from Firestore
    /// - Returns: Array of Pin objects
    /// - Throws: Error if the operation fails
    static func getAllPins() async throws -> [Pin] {
        let snapshot = try await db.collection("pins").getDocuments()
        
        return snapshot.documents.compactMap { document in
            guard let latitude = document.data()["latitude"] as? Double,
                  let longitude = document.data()["longitude"] as? Double,
                  let typeString = document.data()["type"] as? String,
                  let videoURL = document.data()["videoURL"] as? String,
                  let userId = document.data()["userId"] as? String else {
                return nil
            }
            
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            let incidentType = IncidentType.fromFirestoreType(typeString) // Use correct method
            
            return Pin(
                id: document.documentID,
                coordinate: coordinate,
                incidentType: incidentType,
                videoURL: videoURL,
                userId: userId
            )
        }
    }
} 
