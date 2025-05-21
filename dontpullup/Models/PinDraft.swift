import Foundation
import MapKit
import CoreLocation
import FirebaseAuth

struct PinDraft {
    var coordinate: CLLocationCoordinate2D
    var incidentType: IncidentType
    var videoURL: URL?
    var description: String = ""
    
    // Adding these properties for direct coordinate access
    var latitude: Double {
        get { coordinate.latitude }
        set { coordinate = CLLocationCoordinate2D(latitude: newValue, longitude: coordinate.longitude) }
    }
    
    var longitude: Double {
        get { coordinate.longitude }
        set { coordinate = CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: newValue) }
    }
    
    init(coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0),
         incidentType: IncidentType = .verbal,
         videoURL: URL? = nil,
         description: String = "") {
        self.coordinate = coordinate
        self.incidentType = incidentType
        self.videoURL = videoURL
        self.description = description
    }
    
    func makePin(id: String, remote: String) -> Pin {
        return Pin(
            id: id,
            coordinate: coordinate,
            incidentType: incidentType,
            videoURL: remote,
            userId: Auth.auth().currentUser?.uid ?? ""
        )
    }
} 