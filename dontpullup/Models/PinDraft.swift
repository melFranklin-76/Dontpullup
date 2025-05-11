import Foundation
import MapKit
import CoreLocation
import FirebaseAuth

struct PinDraft {
    var coordinate: CLLocationCoordinate2D
    var incidentType: IncidentType
    var videoURL: URL?
    
    init(coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0),
         incidentType: IncidentType = .verbal,
         videoURL: URL? = nil) {
        self.coordinate = coordinate
        self.incidentType = incidentType
        self.videoURL = videoURL
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