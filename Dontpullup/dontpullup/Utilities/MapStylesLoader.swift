import Foundation
import MapKit

/// Helper class to load map style resources
struct MapStylesLoader {
    
    enum StyleType {
        case standard
        case satellite
        case hybrid
        case neon
    }
    
    /// Load the appropriate map style
    static func loadMapStyle(_ type: StyleType) -> MKTileOverlay? {
        // Use ResourceLoader to find the style file
        guard let styleURL = getStyleURL(for: type) else {
            print("Failed to locate map style resource for \(type)")
            return nil
        }
        
        // Create tile overlay with template URL string
        // For local files, we need to ensure proper URLs
        let urlString: String
        if styleURL.isFileURL {
            // For file URLs, we need to ensure they're correctly formatted 
            // The URL must be a valid template
            urlString = styleURL.absoluteString
            print("Using file URL for map style: \(urlString)")
            
            // Create a tile overlay using the file path
            let overlay = MKTileOverlay(urlTemplate: urlString)
            overlay.canReplaceMapContent = false
            return overlay
        } else {
            // For remote URLs
            urlString = styleURL.absoluteString
            print("Using remote URL for map style: \(urlString)")
            
            let overlay = MKTileOverlay(urlTemplate: urlString)
            overlay.canReplaceMapContent = false
            return overlay
        }
    }
    
    /// Get the URL for the style file
    private static func getStyleURL(for type: StyleType) -> URL? {
        let fileExtension = "styl"
        var fileName: String
        
        switch type {
        case .standard:
            fileName = "standard"
        case .satellite:
            fileName = "satellite"
        case .hybrid:
            fileName = "hybrid"
        case .neon:
            fileName = "neon"
        }
        
        // Try different resolutions (iOS tries to load @2x, @3x automatically)
        let resolutions = ["", "@2x", "@3x", "@2.6x"]
        
        for resolution in resolutions {
            let resourceName = "\(fileName)\(resolution)"
            
            // Try using ResourceLoader first
            if let url = ResourceLoader.getResourceURL(name: resourceName, extension: fileExtension, subdirectory: "MapStyles") {
                return url
            }
            
            // Fallback methods
            if let resourceURL = Bundle.main.url(forResource: resourceName, withExtension: fileExtension, subdirectory: "Resources/MapStyles") {
                return resourceURL
            }
            
            if let resourceURL = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) {
                return resourceURL
            }
            
            // Log the attempt for debugging
            print("Failed to locate resource named \"\(resourceName).\(fileExtension)\"")
        }
        
        // If styl not found, try json as fallback
        if let jsonURL = ResourceLoader.getResourceURL(name: fileName, extension: "json", subdirectory: "MapStyles") {
            return jsonURL
        }
        
        if let jsonURL = Bundle.main.url(forResource: fileName, withExtension: "json", subdirectory: "Resources/MapStyles") {
            return jsonURL
        }
        
        if let jsonURL = Bundle.main.url(forResource: fileName, withExtension: "json") {
            return jsonURL
        }
        
        // If all attempts fail, return nil
        if type == .satellite || type == .hybrid {
            print("Couldn't find \(fileName).\(fileExtension) in framework, file name \(fileName).\(fileExtension)")
        }
        
        return nil
    }
} 