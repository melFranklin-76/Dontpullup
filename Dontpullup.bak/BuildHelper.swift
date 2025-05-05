import Foundation
#if canImport(Darwin)
import Darwin
#endif

struct BuildHelper {
    static func setupBuildEnvironment() {
        #if os(macOS)
        do {
            let fileManager = FileManager.default
            let rootPath = "/Users/melfranklin/Music/Dontpullup"
            
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
            
            // Execute commands
            try runCommand("/usr/bin/sudo", ["chown", "-R", "melfranklin:staff", rootPath])
            try runCommand("/bin/chmod", ["-R", "u+w", rootPath])
            try runCommand("/usr/bin/xcodebuild", ["clean", "-project", "Dontpullup.xcodeproj", "-scheme", "Dontpullup"])
            try runCommand("/usr/bin/xcodebuild", ["-project", "Dontpullup.xcodeproj", "-scheme", "Dontpullup"])
        } catch {
            print("Build environment setup failed: \(error.localizedDescription)")
        }
        #else
        // When running in simulator, just log a message instead of throwing an error
        print("BuildHelper: Skipping build environment setup (not running on macOS)")
        #endif
    }
    
    private static func runCommand(_ executable: String, _ arguments: [String]) throws {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            print("Command output: \(output)")
        }
        
        if process.terminationStatus != 0 {
            throw NSError(
                domain: "BuildHelper",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Command failed: \(executable) \(arguments.joined(separator: " "))"]
            )
        }
        #else
        print("BuildHelper: Cannot run command \(executable) (not running on macOS)")
        #endif
    }
}
