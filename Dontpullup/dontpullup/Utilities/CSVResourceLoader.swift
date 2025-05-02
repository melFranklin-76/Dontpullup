import Foundation

/// A utility class for loading CSV resources from the bundle
struct CSVResourceLoader {
    
    enum CSVLoadError: Error {
        case fileNotFound
        case invalidData
    }
    
    /// Loads a CSV file from the bundle
    /// - Parameter fileName: The name of the CSV file without extension
    /// - Returns: Array of dictionaries, where each dictionary represents a row
    static func loadCSV(fileName: String) -> [[String: String]]? {
        do {
            // Try multiple locations
            let data = try loadCSVData(fileName: fileName)
            return try parseCSV(data: data)
        } catch {
            print("Failed to locate resource named \"\(fileName).csv\": \(error)")
            return nil
        }
    }
    
    /// Loads CSV data from the bundle, trying multiple locations
    private static func loadCSVData(fileName: String) throws -> Data {
        // First use the ResourceLoader to try multiple locations
        if let url = ResourceLoader.getResourceURL(name: fileName, extension: "csv") {
            print("Found CSV at: \(url.path)")
            return try Data(contentsOf: url)
        }
        
        // Fallback to direct bundle loading with additional paths
        let locations = [
            // Try directly in the bundle root
            Bundle.main.url(forResource: fileName, withExtension: "csv"),
            
            // Try in Resources directory
            Bundle.main.url(forResource: fileName, withExtension: "csv", subdirectory: "Resources"),
            
            // Try with absolute path if we know Resources structure
            Bundle.main.bundleURL.appendingPathComponent("Resources/\(fileName).csv"),
            
            // Try in cache directory
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("\(fileName).csv")
        ]
        
        // Try each location
        for location in locations {
            if let url = location {
                print("Trying CSV at: \(url.path)")
                if FileManager.default.fileExists(atPath: url.path), let data = try? Data(contentsOf: url) {
                    print("Successfully loaded CSV from: \(url.path)")
                    return data
                }
            }
        }
        
        // If we get here, create a fallback CSV in memory
        print("Could not find \(fileName).csv file in any location, using fallback content")
        let csvContent = """
        type,color,icon
        911,#FF0000,emergency_icon
        Physical,#FF4500,physical_icon
        Verbal,#FFA500,verbal_icon
        """
        
        if let data = csvContent.data(using: .utf8) {
            // Try to write this to cache for future use
            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            let csvURL = cacheDir.appendingPathComponent("\(fileName).csv")
            try? csvContent.write(to: csvURL, atomically: true, encoding: .utf8)
            print("Created fallback \(fileName).csv in cache directory")
            
            // Also try to write to the app's Resources directory
            let bundleResourceDir = Bundle.main.bundleURL.appendingPathComponent("Resources")
            if !FileManager.default.fileExists(atPath: bundleResourceDir.path) {
                try? FileManager.default.createDirectory(at: bundleResourceDir, withIntermediateDirectories: true)
            }
            let bundleURL = bundleResourceDir.appendingPathComponent("\(fileName).csv")
            try? csvContent.write(to: bundleURL, atomically: true, encoding: .utf8)
            print("Also wrote fallback \(fileName).csv to bundle Resources directory")
            
            return data
        }
        
        // If all attempts fail
        throw CSVLoadError.fileNotFound
    }
    
    /// Parses CSV data into an array of dictionaries
    private static func parseCSV(data: Data) throws -> [[String: String]] {
        guard let content = String(data: data, encoding: .utf8) else {
            throw CSVLoadError.invalidData
        }
        
        // Split by lines
        var lines = content.components(separatedBy: .newlines)
        
        // Remove empty lines
        lines = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        guard !lines.isEmpty else {
            throw CSVLoadError.invalidData
        }
        
        // Get headers from first line
        let headers = lines[0].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        guard !headers.isEmpty else {
            throw CSVLoadError.invalidData
        }
        
        // Process each line
        var result: [[String: String]] = []
        for i in 1..<lines.count {
            let values = lines[i].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard values.count == headers.count else {
                // Skip malformed rows
                continue
            }
            
            // Create dictionary for this row
            var row: [String: String] = [:]
            for (index, header) in headers.enumerated() {
                row[header] = values[index]
            }
            
            result.append(row)
        }
        
        return result
    }
} 