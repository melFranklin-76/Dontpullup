import UIKit
import Firebase
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

@main
class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("AppDelegate: Application launching")
        
        // Configure Firebase
        FirebaseApp.configure()
        
        // Ensure the app is configured to sync with the root folder automatically
        syncWithRootFolder()
        
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Handle discarded scenes if needed
    }
    
    private func syncWithRootFolder() {
        // Add any missing files from the root folder to the project
        let fileManager = FileManager.default
        let rootFolderURL = URL(fileURLWithPath: "/Users/melfranklin/Desktop/dontbullup_Backup")
        let projectFolderURL = URL(fileURLWithPath: "/Users/melfranklin/Desktop/dontbullup_Backup")
        let buildFolderURL = URL(fileURLWithPath: "/Users/melfranklin/Desktop/dontbullup_Backup/build")
        
        do {
            let rootFolderContents = try fileManager.contentsOfDirectory(at: rootFolderURL, includingPropertiesForKeys: nil, options: [])
            for fileURL in rootFolderContents {
                let destinationURL = projectFolderURL.appendingPathComponent(fileURL.lastPathComponent)
                if !fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.copyItem(at: fileURL, to: destinationURL)
                }
            }
            
            // Sync build folder
            let buildFolderContents = try fileManager.contentsOfDirectory(at: buildFolderURL, includingPropertiesForKeys: nil, options: [])
            for fileURL in buildFolderContents {
                let destinationURL = projectFolderURL.appendingPathComponent("build").appendingPathComponent(fileURL.lastPathComponent)
                if !fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.copyItem(at: fileURL, to: destinationURL)
                }
            }
        } catch {
            print("Error syncing with root folder: \(error)")
        }
    }
}
