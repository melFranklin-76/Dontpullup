import UIKit
import Firebase
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("AppDelegate: Application launching")
        
        // Configure Firebase
        FirebaseApp.configure()
        
        // Setup all resources needed for the app to run
        ResourceLoader.setupAppResources()
        
        // Verify default.csv is accessible and preload it
        verifyDefaultResources()
        
        // Removed placeholder syncWithRootFolder() call – unnecessary for production and caused runtime errors when the hard‑coded path didn't exist.
        
        return true
    }
    
    /// Verify default resources are accessible
    private func verifyDefaultResources() {
        // Check if default.csv is accessible
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let csvURL = cacheDir.appendingPathComponent("default.csv")
        
        if fileManager.fileExists(atPath: csvURL.path) {
            print("Verified default.csv exists in cache: \(csvURL.path)")
            
            // Try to preload it to ensure it's valid
            do {
                let csvData = try Data(contentsOf: csvURL)
                print("Successfully verified default.csv content")
                
                // Also write to the main bundle's Resources directory for direct loading
                tryWritingToResourcesDirectory(data: csvData)
                
            } catch {
                print("Warning: default.csv exists but couldn't be read: \(error)")
            }
        } else {
            print("Warning: default.csv not found in cache, creating it...")
            // Create the default CSV content explicitly
            let csvContent = """
            type,color,icon
            911,#FF0000,emergency_icon
            Physical,#FF4500,physical_icon
            Verbal,#FFA500,verbal_icon
            """
            
            try? csvContent.write(to: csvURL, atomically: true, encoding: .utf8)
            print("Created default.csv manually in cache directory")
            
            // Also write to Resources directory
            if let data = csvContent.data(using: .utf8) {
                tryWritingToResourcesDirectory(data: data)
            }
        }
    }
    
    /// Write the CSV to multiple places where code might look for it
    private func tryWritingToResourcesDirectory(data: Data) {
        // Try to write to Resources subdirectory in main bundle
        if let resourcesURL = Bundle.main.bundleURL.appendingPathComponent("Resources", isDirectory: true) as URL? {
            let fileManager = FileManager.default
            
            // Create directory if it doesn't exist
            if !fileManager.fileExists(atPath: resourcesURL.path) {
                try? fileManager.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
            }
            
            let csvURL = resourcesURL.appendingPathComponent("default.csv")
            do {
                try data.write(to: csvURL)
                print("Successfully copied default.csv to bundle Resources directory: \(csvURL.path)")
            } catch {
                print("Warning: Could not write to bundle Resources directory: \(error)")
            }
        }
        
        // Also try to write to the Documents directory as another fallback
        if let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let csvURL = docsURL.appendingPathComponent("default.csv")
            try? data.write(to: csvURL)
        }
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Handle discarded scenes if needed
    }
    
    // Placeholder syncWithRootFolder() removed – handled by asset catalogs and Xcode build phases.
}
