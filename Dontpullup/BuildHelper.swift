import Foundation

struct BuildHelper {
    static func setupBuildEnvironment() throws {
        let fileManager = FileManager.default
        let rootPath = "/Users/melfranklin/Documents/Dontpullup"
        
        // Ensure we have access to DerivedData
        let derivedDataPath = "~/Library/Developer/Xcode/DerivedData"
        try fileManager.createDirectory(
            atPath: (derivedDataPath as NSString).expandingTildeInPath,
            withIntermediateDirectories: true
        )
        
        // Set correct permissions
        try fileManager.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: rootPath
        )
        
        // Grant necessary permissions
        let process = Process()
        process.launchPath = "/usr/bin/sudo"
        process.arguments = ["chown", "-R", "melfranklin:staff", rootPath]
        process.launch()
        process.waitUntilExit()
        
        let chmodProcess = Process()
        chmodProcess.launchPath = "/bin/chmod"
        chmodProcess.arguments = ["-R", "u+w", rootPath]
        chmodProcess.launch()
        chmodProcess.waitUntilExit()
        
        // Clean build artifacts
        let cleanProcess = Process()
        cleanProcess.launchPath = "/usr/bin/xcodebuild"
        cleanProcess.arguments = ["clean", "-workspace", "dontpullup.xcworkspace", "-scheme", "dontpullup"]
        cleanProcess.launch()
        cleanProcess.waitUntilExit()
        
        // Build from root
        let buildProcess = Process()
        buildProcess.launchPath = "/usr/bin/xcodebuild"
        buildProcess.arguments = ["-workspace", "dontpullup.xcworkspace", "-scheme", "dontpullup"]
        buildProcess.launch()
        buildProcess.waitUntilExit()
    }
}
