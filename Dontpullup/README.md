# Firebase Logging Management

## Overview

This document describes how to use the LoggingManager utility to manage Firebase logs in the application.

## Using LoggingManager

The LoggingManager provides a way to control Firebase logs verbosity and filter logs by service.

### Basic Usage

```swift
// Set log level
LoggingManager.shared.setLogLevel(.info)

// Enable logging for specific services
LoggingManager.shared.enableLogging(for: [.analytics, .auth])

// Enable verbose logging during development
LoggingManager.shared.enableVerboseLogging()

// Disable all logs for production
LoggingManager.shared.disableAllLogs()

// Save logs to a file
if let logFileURL = LoggingManager.shared.saveLogs() {
    print("Logs saved to: \(logFileURL)")
}
```

### Resolving Constraint Issues

The Firebase logs show multiple constraint issues. To debug these:

1. Use the LoggingExtensions to identify problematic constraints:

```swift
// In your view controller when you suspect constraint issues
LoggingManager.shared.logConstraintIssue(view: problematicView)
```

2. Create symbolic breakpoints as suggested by the utility:

```swift
LoggingManager.shared.setupConstraintDebugging()
```

3. Check for common issues:
   - Conflicting height constraints on SystemInputAssistantView
   - Keyboard compatibility issues
   - Overlapping UI elements with ambiguous constraints

## Integration with AppDelegate

Add the following code to your AppDelegate to configure logging at startup:

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Configure Firebase
    FirebaseApp.configure()
    
    // Set up logging (adjust for your environment)
    #if DEBUG
    LoggingManager.shared.setLogLevel(.debug)
    LoggingManager.shared.enableLogging(for: [.analytics, .auth])
    #else
    LoggingManager.shared.setLogLevel(.error)
    #endif
    
    return true
}
```
