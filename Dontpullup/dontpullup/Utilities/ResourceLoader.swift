import Foundation
import MapKit

/// A utility class for loading resources at runtime
class ResourceLoader {
    
    /// Setup all resources needed for the app to work
    static func setupAppResources() {
        // Ensure MapStyles directory exists in cache
        let styles = createMapStyleFiles()
        print("Created \(styles) map style files in cache directory")
        
        // Load CSV data
        loadDefaultCSV()
    }
    
    /// Create map style files in cache directory for runtime use
    private static func createMapStyleFiles() -> Int {
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let stylesDir = cacheDir.appendingPathComponent("MapStyles", isDirectory: true)
        
        // Create MapStyles directory if it doesn't exist
        if !fileManager.fileExists(atPath: stylesDir.path) {
            try? fileManager.createDirectory(at: stylesDir, withIntermediateDirectories: true)
        }
        
        var createdCount = 0
        
        // Create standard.styl
        let standardContent = """
        {
          "version": 8,
          "name": "Standard",
          "sources": {
            "mapbox": {
              "type": "vector"
            }
          },
          "layers": []
        }
        """
        
        let standardStyles = [
            "standard.styl",
            "standard@2x.styl",
            "standard@3x.styl"
        ]
        
        for style in standardStyles {
            let styleURL = stylesDir.appendingPathComponent(style)
            if !fileManager.fileExists(atPath: styleURL.path) {
                try? standardContent.write(to: styleURL, atomically: true, encoding: .utf8)
                createdCount += 1
            }
        }
        
        // Create satellite styles
        let satelliteContent = """
        {
          "version": 8,
          "name": "Satellite",
          "sources": {
            "mapbox": {
              "type": "vector"
            }
          },
          "layers": []
        }
        """
        
        let satelliteStyles = [
            "satellite.styl",
            "satellite@2x.styl",
            "satellite@2.6x.styl",
            "satellite@3x.styl"
        ]
        
        for style in satelliteStyles {
            let styleURL = stylesDir.appendingPathComponent(style)
            if !fileManager.fileExists(atPath: styleURL.path) {
                try? satelliteContent.write(to: styleURL, atomically: true, encoding: .utf8)
                createdCount += 1
            }
        }
        
        return createdCount
    }
    
    /// Load default CSV data
    private static func loadDefaultCSV() {
        // Create the default CSV content
        let csvContent = """
        type,color,icon
        911,#FF0000,emergency_icon
        Physical,#FF4500,physical_icon
        Verbal,#FFA500,verbal_icon
        """
        
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let csvURL = cacheDir.appendingPathComponent("default.csv")
        
        if !fileManager.fileExists(atPath: csvURL.path) {
            try? csvContent.write(to: csvURL, atomically: true, encoding: .utf8)
            print("Created default.csv in cache directory")
        }
    }
    
    /// Get URL for resource file, checking multiple locations
    static func getResourceURL(name: String, extension ext: String, subdirectory: String? = nil) -> URL? {
        // First check the bundle
        if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdirectory) {
            print("Resource found in bundle: \(url.path)")
            return url
        }
        
        // Check Resources subdirectory in the bundle
        if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Resources" + (subdirectory != nil ? "/\(subdirectory!)" : "")) {
            print("Resource found in Resources subdirectory: \(url.path)")
            return url
        }
        
        // Check cache directory
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        
        if let subdirectory = subdirectory {
            let subfolderPath = cacheDir.appendingPathComponent(subdirectory, isDirectory: true)
            
            // Create directory if doesn't exist
            if !fileManager.fileExists(atPath: subfolderPath.path) {
                try? fileManager.createDirectory(at: subfolderPath, withIntermediateDirectories: true)
            }
            
            let cacheURL = subfolderPath.appendingPathComponent("\(name).\(ext)")
            if fileManager.fileExists(atPath: cacheURL.path) {
                print("Resource found in cache subdirectory: \(cacheURL.path)")
                return cacheURL
            }
        } else {
            let cacheURL = cacheDir.appendingPathComponent("\(name).\(ext)")
            if fileManager.fileExists(atPath: cacheURL.path) {
                print("Resource found in cache root: \(cacheURL.path)")
                return cacheURL
            }
        }
        
        // Check documents directory
        let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if let subdirectory = subdirectory {
            let docsURL = docsDir.appendingPathComponent(subdirectory, isDirectory: true).appendingPathComponent("\(name).\(ext)")
            if fileManager.fileExists(atPath: docsURL.path) {
                print("Resource found in documents subdirectory: \(docsURL.path)")
                return docsURL
            }
        } else {
            let docsURL = docsDir.appendingPathComponent("\(name).\(ext)")
            if fileManager.fileExists(atPath: docsURL.path) {
                print("Resource found in documents directory: \(docsURL.path)")
                return docsURL
            }
        }
        
        print("Failed to locate resource named \"\(name).\(ext)\"")
        return nil
    }
} 