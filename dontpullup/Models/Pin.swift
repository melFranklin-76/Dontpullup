import MapKit

/**
 The Pin struct represents a pin on the map.
 It conforms to the Identifiable and Codable protocols.
 */
struct Pin: Identifiable, Codable {
    /// Unique identifier for the pin.
    let id: String
    /// Coordinate of the pin on the map.
    let coordinate: CLLocationCoordinate2D
    /// Type of incident associated with the pin.
    let incidentType: IncidentType
    /// URL of the video associated with the pin.
    let videoURL: String
    /// User ID of the person who created the pin.
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case latitude
        case longitude
        case incidentType
        case videoURL
        case userId
    }
    
    /**
     Initializes a new Pin instance.
     
     - Parameters:
        - id: Unique identifier for the pin.
        - coordinate: Coordinate of the pin on the map.
        - incidentType: Type of incident associated with the pin.
        - videoURL: URL of the video associated with the pin.
        - userId: User ID of the person who created the pin.
     */
    init(id: String, coordinate: CLLocationCoordinate2D, incidentType: IncidentType, videoURL: String, userId: String) {
        self.id = id
        self.coordinate = coordinate
        self.incidentType = incidentType
        self.videoURL = videoURL
        self.userId = userId
    }
    
    /**
     Initializes a new Pin instance from a decoder.
     
     - Parameter decoder: The decoder to read data from.
     - Throws: An error if decoding fails.
     */
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        incidentType = try container.decode(IncidentType.self, forKey: .incidentType)
        videoURL = try container.decode(String.self, forKey: .videoURL)
        userId = try container.decode(String.self, forKey: .userId)
    }
    
    /**
     Encodes the Pin instance to an encoder.
     
     - Parameter encoder: The encoder to write data to.
     - Throws: An error if encoding fails.
     */
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(incidentType, forKey: .incidentType)
        try container.encode(videoURL, forKey: .videoURL)
        try container.encode(userId, forKey: .userId)
    }
}
