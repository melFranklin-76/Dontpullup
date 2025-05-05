import Foundation
import SwiftUI

/// This file establishes the main module naming and types
/// with explicit cross-references to avoid circular dependencies

// Re-export necessary standard modules
// @_exported import SwiftUI
// @_exported import Foundation
// @_exported import MapKit
// @_exported import AVKit

// Module Constants
public enum AppConstants {
    public static let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? "Don't Pull Up"
    public static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    public static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
} 