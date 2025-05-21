import CoreGraphics
import UIKit
import MapKit
import CoreLocation

// Extensions to prevent NaN values in Core Graphics calculations
extension CGFloat {
    /// Returns a safe value, replacing NaN or Infinity with a default value
    func validated(default defaultValue: CGFloat = 0) -> CGFloat {
        return self.isNaN || self.isInfinite ? defaultValue : self
    }
    
    /// Returns a value clamped between min and max, and handles NaN/Infinity
    func clamped(min: CGFloat, max: CGFloat, default defaultValue: CGFloat = 0) -> CGFloat {
        guard !self.isNaN && !self.isInfinite else { return defaultValue }
        return Swift.min(Swift.max(self, min), max)
    }
    
    /// Safely converts to Int, returning 0 for NaN or Infinity
    func toSafeInt() -> Int {
        guard !self.isNaN && !self.isInfinite else { return 0 }
        return Int(self)
    }
}

extension CGPoint {
    /// Returns a point with validated coordinates
    func validated(default defaultValue: CGFloat = 0) -> CGPoint {
        return CGPoint(
            x: x.validated(default: defaultValue),
            y: y.validated(default: defaultValue)
        )
    }
}

extension CGSize {
    /// Returns a size with validated dimensions
    func validated(default defaultValue: CGFloat = 0) -> CGSize {
        return CGSize(
            width: width.validated(default: defaultValue),
            height: height.validated(default: defaultValue)
        )
    }
    
    /// Returns a size with positive dimensions, handling NaN/Infinity
    func validatedPositive(default defaultValue: CGFloat = 1) -> CGSize {
        return CGSize(
            width: width.clamped(min: 0.1, max: 10000, default: defaultValue),
            height: height.clamped(min: 0.1, max: 10000, default: defaultValue)
        )
    }
}

extension CGRect {
    /// Returns a rect with validated components
    func validated(default defaultValue: CGFloat = 0) -> CGRect {
        return CGRect(
            origin: origin.validated(default: defaultValue),
            size: size.validated(default: defaultValue)
        )
    }
    
    /// Returns a rect with valid positive size
    func validatedPositive(default defaultValue: CGFloat = 1) -> CGRect {
        return CGRect(
            origin: origin.validated(default: defaultValue),
            size: size.validatedPositive(default: defaultValue)
        )
    }
}

// Extensions for validating CLLocationCoordinate2D
extension CLLocationCoordinate2D {
    /// Returns a validated coordinate with valid latitude (-90 to 90) and longitude (-180 to 180)
    /// If either value is NaN or infinite, it will be replaced with the default value
    func validated(defaultLat: CLLocationDegrees = 0, defaultLng: CLLocationDegrees = 0) -> CLLocationCoordinate2D {
        let validLat = latitude.isNaN || latitude.isInfinite ? 
            defaultLat : min(max(latitude, -90), 90)
        let validLng = longitude.isNaN || longitude.isInfinite ? 
            defaultLng : min(max(longitude, -180), 180)
        
        return CLLocationCoordinate2D(latitude: validLat, longitude: validLng)
    }
    
    /// Returns if coordinate has valid values (not NaN or infinite)
    var isValid: Bool {
        return !latitude.isNaN && !latitude.isInfinite && 
               !longitude.isNaN && !longitude.isInfinite &&
               latitude >= -90 && latitude <= 90 &&
               longitude >= -180 && longitude <= 180
    }
    
    /// Returns a safe coordinate for creating MapKit points
    /// Invalid coordinates will be replaced with safe values
    var safeForMapKit: CLLocationCoordinate2D {
        return validated()
    }
}

// Extension for safely converting between coordinates and map points
extension MKMapPoint {
    /// Creates a map point with validated coordinates
    init(safeCoordinate coordinate: CLLocationCoordinate2D) {
        self.init(coordinate.validated())
    }
}

// Extension to prevent crashes when converting Double to Int
extension Double {
    /// Safely converts to Int, returning 0 for NaN or Infinity
    func toSafeInt() -> Int {
        guard !self.isNaN && !self.isInfinite else { return 0 }
        return Int(self)
    }
} 