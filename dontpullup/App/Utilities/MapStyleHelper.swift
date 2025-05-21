import Foundation
import MapKit

/// Helper class for handling map style resources
public enum MapStyleHelper {
    
    /// Ensures map style files are copied to an accessible location for MapKit to use
    public static func copyMapStylesToAccessibleLocation() {
        let fileManager = FileManager.default
        
        // Get the DocumentDirectory URL for saving styles where app can access them
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[MapStyleHelper] Error: Could not access documents directory")
            return
        }
        
        // Create a MapStyles directory in documents if it doesn't exist
        let mapStylesDirectory = documentsDirectory.appendingPathComponent("MapStyles", isDirectory: true)
        
        do {
            if !fileManager.fileExists(atPath: mapStylesDirectory.path) {
                try fileManager.createDirectory(at: mapStylesDirectory, withIntermediateDirectories: true)
                print("[MapStyleHelper] Created MapStyles directory in Documents")
            }
            
            // Get the bundle resource directory
            guard let resourcesDirectory = Bundle.main.resourceURL?.appendingPathComponent("MapStyles", isDirectory: true) else {
                print("[MapStyleHelper] Error: Could not locate MapStyles directory in bundle")
                return
            }
            
            // Try to list files in the resource directory
            guard let resourceFiles = try? fileManager.contentsOfDirectory(at: resourcesDirectory, includingPropertiesForKeys: nil) else {
                print("[MapStyleHelper] Error: Could not read contents of MapStyles directory")
                return
            }
            
            // Copy each file to the documents directory
            for resourceFile in resourceFiles {
                let fileName = resourceFile.lastPathComponent
                let destinationURL = mapStylesDirectory.appendingPathComponent(fileName)
                
                // Only copy if the file doesn't exist or is newer
                if !fileManager.fileExists(atPath: destinationURL.path) ||
                   isSourceFileNewer(sourceURL: resourceFile, destinationURL: destinationURL) {
                    try fileManager.copyItem(at: resourceFile, to: destinationURL)
                    print("[MapStyleHelper] Copied \(fileName) to Documents/MapStyles")
                }
            }
            
            print("[MapStyleHelper] Successfully prepared map style resources")
        } catch {
            print("[MapStyleHelper] Error preparing map style resources: \(error.localizedDescription)")
        }
    }
    
    /// Check if source file is newer than destination file
    private static func isSourceFileNewer(sourceURL: URL, destinationURL: URL) -> Bool {
        do {
            let sourceAttributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
            let destinationAttributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
            
            if let sourceDate = sourceAttributes[.modificationDate] as? Date,
               let destinationDate = destinationAttributes[.modificationDate] as? Date {
                return sourceDate > destinationDate
            }
        } catch {
            // If there's an error checking, assume we should copy
            return true
        }
        return true
    }
    
    /// Returns the URL for a map style file from the accessible location
    /// - Parameters:
    ///   - name: The name of the style file without extension
    ///   - extension: The file extension
    /// - Returns: URL to the style file, or nil if not found
    public static func urlForMapStyle(named name: String, extension ext: String) -> URL? {
        let fileManager = FileManager.default
        
        if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let styleURL = documentsDirectory.appendingPathComponent("MapStyles/\(name).\(ext)")
            if fileManager.fileExists(atPath: styleURL.path) {
                print("[MapStyleHelper] Found map style at: \(styleURL.path)")
                return styleURL
            }
        }
        
        return nil
    }
} 