import Foundation
import MapKit
import AVFoundation

enum Environment {
    case development
    case staging
    case production
    
    static var current: Environment {
        #if DEBUG
        return .development
        #else
        if Bundle.main.bundleIdentifier?.contains("staging") == true {
            return .staging
        }
        return .production
        #endif
    }
}

struct AppConfig {
    static let shared = AppConfig()
    
    // Firebase Configuration
    struct Firebase {
        let storageURLPrefix: String
        let maxUploadSize: Int64
        let maxConcurrentUploads: Int
        
        static var current: Firebase {
            switch Environment.current {
            case .development:
                return Firebase(
                    storageURLPrefix: "gs://dontpullup-dev.appspot.com",
                    maxUploadSize: 100 * 1024 * 1024,
                    maxConcurrentUploads: 3
                )
            case .staging:
                return Firebase(
                    storageURLPrefix: "gs://dontpullup-staging.appspot.com",
                    maxUploadSize: 200 * 1024 * 1024,
                    maxConcurrentUploads: 5
                )
            case .production:
                return Firebase(
                    storageURLPrefix: "gs://dontpullup.appspot.com",
                    maxUploadSize: 500 * 1024 * 1024,
                    maxConcurrentUploads: 10
                )
            }
        }
    }
    
    // Video Processing Configuration
    struct Video {
        let maxDuration: TimeInterval
        let compressionQuality: String
        let targetBitrate: Int
        let maxFileSize: Int64
        
        static var current: Video {
            switch Environment.current {
            case .development:
                return Video(
                    maxDuration: 60,
                    compressionQuality: AVAssetExportPresetMediumQuality,
                    targetBitrate: 2_000_000,
                    maxFileSize: 50 * 1024 * 1024
                )
            case .staging, .production:
                return Video(
                    maxDuration: 180,
                    compressionQuality: AVAssetExportPresetHEVCHighestQuality,
                    targetBitrate: 4_000_000,
                    maxFileSize: 200 * 1024 * 1024
                )
            }
        }
    }
    
    // Cache Configuration
    struct Cache {
        let maxMemorySize: Int
        let maxDiskSize: Int64
        let expirationInterval: TimeInterval
        
        static var current: Cache {
            switch Environment.current {
            case .development:
                return Cache(
                    maxMemorySize: 50 * 1024 * 1024,
                    maxDiskSize: 200 * 1024 * 1024,
                    expirationInterval: 24 * 3600
                )
            case .staging, .production:
                return Cache(
                    maxMemorySize: 100 * 1024 * 1024,
                    maxDiskSize: 500 * 1024 * 1024,
                    expirationInterval: 7 * 24 * 3600
                )
            }
        }
    }
    
    // Map Configuration
    struct Map {
        let maxPinDistance: CLLocationDistance
        let defaultZoomLevel: Double
        let clusteringRadius: Double
        
        static var current: Map {
            Map(
                maxPinDistance: 61, // 200 feet in meters
                defaultZoomLevel: 0.02,
                clusteringRadius: 100
            )
        }
    }
} 