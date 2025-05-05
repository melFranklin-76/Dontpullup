import Foundation
import MapKit

public struct Pin: Identifiable, Codable {
    public let id: String
    public let coordinate: CLLocationCoordinate2D
    public let incidentType: IncidentType
    public let videoURL: String
    public let userId: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case latitude
        case longitude
        case type
        case videoURL
        case userId
    }
    
    public init(id: String, coordinate: CLLocationCoordinate2D, incidentType: IncidentType, videoURL: String, userId: String) {
        self.id = id
        self.coordinate = coordinate
        self.incidentType = incidentType
        self.videoURL = videoURL
        self.userId = userId
    }
    
    // Custom Codable implementation for CLLocationCoordinate2D
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        
        // Decode coordinate components
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        // Decode incident type
        let typeString = try container.decode(String.self, forKey: .type)
        if let type = IncidentType(rawValue: typeString) {
            incidentType = type
        } else {
            // Try to decode from firestore type
            incidentType = IncidentType.fromFirestoreType(typeString)
        }
        
        videoURL = try container.decode(String.self, forKey: .videoURL)
        userId = try container.decode(String.self, forKey: .userId)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        
        // Encode coordinate components
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        
        // Encode incident type
        try container.encode(incidentType.firestoreType, forKey: .type)
        
        try container.encode(videoURL, forKey: .videoURL)
        try container.encode(userId, forKey: .userId)
    }
} 