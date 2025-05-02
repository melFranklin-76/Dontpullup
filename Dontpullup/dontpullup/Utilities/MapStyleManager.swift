import MapKit
import Foundation

/// Loads and applies custom map styling for the app.
/// For custom styling, create a .json style file and place it in the app bundle.
enum MapStyleManager {
    /// Applies styling to the given MKMapView
    static func applyCustomStyle(to mapView: MKMapView) {
        // Set basic styling properties directly
        mapView.mapType = .standard
        // Rely on system appearance; forcing dark can prevent tile loading on some simulator builds
        // mapView.overrideUserInterfaceStyle = .dark
        
        // For iOS 16+ apps, Apple recommends their official Map Style Designer:
        // https://mapdesigner.apple.com
        // Just drop the .mapstyle bundle from there into your app's Resources folder
        
        // Basic customizations that work on all iOS versions
        mapView.showsBuildings = false
        mapView.showsTraffic = false
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        
        // Use a vibrant tint for map elements
        mapView.tintColor = UIColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 1.0)
        
        // Configure user location view appearance
        if let userLocationView = mapView.view(for: mapView.userLocation) {
            userLocationView.tintColor = UIColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 1.0)
            userLocationView.canShowCallout = false
        }
        
        // Set default camera position
        let camera = MKMapCamera()
        camera.pitch = 0
        camera.altitude = 1000 // Match MapViewConstants.defaultAltitude
        mapView.camera = camera
    }
} 