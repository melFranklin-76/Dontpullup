import MapKit

struct Pin: Identifiable, Codable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let incidentType: IncidentType
    let videoURL: String
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case latitude
        case longitude
        case incidentType
        case videoURL
        case userId
    }
    
    init(id: String, coordinate: CLLocationCoordinate2D, incidentType: IncidentType, videoURL: String, userId: String) {
        self.id = id
        self.coordinate = coordinate
        self.incidentType = incidentType
        self.videoURL = videoURL
        self.userId = userId
    }
    
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