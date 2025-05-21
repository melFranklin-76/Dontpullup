import Foundation
import CoreLocation
import MapKit

// MARK: - Double Extensions

extension Double {
    /// Truncates a double to a specific number of decimal places for display purposes
    func truncated(to places: Int = 3) -> Double {
        let divisor = pow(10.0, Double(places))
        return Darwin.round(self * divisor) / divisor
    }
    
    /// Validates a double, returning 0 if NaN or infinite
    func validated() -> Double {
        return self.isNaN || self.isInfinite ? 0.0 : self
    }
}

// MARK: - Coordinate Extensions

extension CLLocationCoordinate2D {
    /// Returns a validated coordinate, replacing NaN/infinite values with safe defaults
    func validated() -> CLLocationCoordinate2D {
        let validLat = self.latitude.isNaN || self.latitude.isInfinite ? 0.0 : self.latitude
        let validLong = self.longitude.isNaN || self.longitude.isInfinite ? 0.0 : self.longitude
        return CLLocationCoordinate2D(latitude: validLat, longitude: validLong)
    }
    
    /// Returns true if the coordinate contains NaN or infinite values
    var isInvalid: Bool {
        return self.latitude.isNaN || self.latitude.isInfinite || 
               self.longitude.isNaN || self.longitude.isInfinite
    }
}

// MARK: - Error Extensions

extension Error {
    /// Provides a simplified error message for common errors
    var simplifiedErrorMessage: String {
        let nsError = self as NSError
        
        // Check for common error domains and codes
        switch nsError.domain {
        case NSURLErrorDomain:
            // Network errors
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return "No internet connection"
            case NSURLErrorTimedOut:
                return "Connection timed out"
            case NSURLErrorNetworkConnectionLost:
                return "Network connection was lost"
            default:
                return "Network error"
            }
            
        case "kCLErrorDomain":
            // Location errors
            switch nsError.code {
            case 1: // kCLErrorDenied
                return "Location access denied"
            case 0: // kCLErrorLocationUnknown
                return "Location is temporarily unavailable"
            case 2: // kCLErrorNetwork
                return "Location unavailable due to network issues"
            default:
                return "Location error"
            }
            
        default:
            // Check error description for common patterns
            let description = self.localizedDescription.lowercased()
            
            if description.contains("permission") || description.contains("denied") {
                return "Permission denied"
            } else if description.contains("network") || description.contains("internet") || description.contains("connection") {
                return "Network error"
            } else if description.contains("timeout") || description.contains("timed out") {
                return "Request timed out"
            } else if description.contains("not found") {
                return "Resource not found"
            } else if description.contains("too large") || description.contains("size") {
                return "File size too large"
            } else if description.contains("already exists") {
                return "Item already exists"
            }
            
            // Fall back to the original description if no patterns match
            return self.localizedDescription
        }
    }
}

// MARK: - Map Style Utilities
extension Bundle {
    /// Helper function to correctly load map style resources
    /// - Parameters:
    ///   - name: The resource name
    ///   - ext: The resource extension (default: "styl")
    /// - Returns: The URL to the resource, or nil if not found
    static func mapStyleURL(name: String, ext: String = "styl") -> URL? {
        // First try the document directory (copied files)
        if let docURL = MapStyleHelper.urlForMapStyle(named: name, extension: ext) {
            print("Found style in documents: \(docURL.path)")
            return docURL
        }
        
        // Next try to load from the main bundle
        if let styleURL = Bundle.main.url(forResource: name, withExtension: ext) {
            print("Found style at main bundle path: \(styleURL.path)")
            return styleURL
        }
        
        // Try to find it in Resources/MapStyles directory
        let resourcePath = Bundle.main.bundlePath + "/Resources/MapStyles"
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: resourcePath) {
            let filePath = resourcePath + "/\(name).\(ext)"
            if fileManager.fileExists(atPath: filePath),
               let styleURL = URL(string: "file://" + filePath) {
                print("Found style at Resources/MapStyles path: \(styleURL.path)")
                return styleURL
            }
        }
        
        // Try to copy files to accessible location if not found
        MapStyleHelper.copyMapStylesToAccessibleLocation()
        
        // Try document directory again after copying
        if let docURL = MapStyleHelper.urlForMapStyle(named: name, extension: ext) {
            print("Found style in documents after copying: \(docURL.path)")
            return docURL
        }
        
        print("Failed to locate resource named \"\(name).\(ext)\"")
        return nil
    }
} 