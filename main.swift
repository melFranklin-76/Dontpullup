import Foundation

print("Starting build environment setup...")

do {
    try BuildHelper.setupBuildEnvironment()
    print("Build environment setup completed successfully")
} catch {
    print("Error setting up build environment: \(error)")
} 