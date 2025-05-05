import Foundation
import CoreLocation

class RestoreManager {
    static func restoreFromCache() -> [Pin]? {
        // Check UserDefaults
        if let data = UserDefaults.standard.data(forKey: "CachedPins"),
           let pins = try? JSONDecoder().decode([Pin].self, from: data) {
            return pins
        }
        return nil
    }
    
    static func restoreFromFileSystem() -> [URL]? {
        let fileManager = FileManager.default
        let cachesPath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let videoCachePath = cachesPath.appendingPathComponent("VideoCache")
        
        // Check if directory exists before attempting to list contents
        if !fileManager.fileExists(atPath: videoCachePath.path) {
            do {
                try fileManager.createDirectory(at: videoCachePath, withIntermediateDirectories: true)
            } catch {
                print("Error creating video cache directory: \(error)")
                return nil
            }
        }
        
        // Return any cached video files
        return try? fileManager.contentsOfDirectory(at: videoCachePath, includingPropertiesForKeys: nil)
    }
    
    static func quickRestore() -> [URL]? {
        // Get cached videos
        if let cachedVideos = restoreFromFileSystem() {
            print("Found \(cachedVideos.count) cached videos")
            return cachedVideos
        }
        return nil
    }
}
