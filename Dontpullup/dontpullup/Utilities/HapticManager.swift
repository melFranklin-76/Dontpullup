import UIKit

/// A utility class to provide haptic feedback throughout the app
class HapticManager {
    
    /// The different types of haptic feedback available
    enum FeedbackType {
        case light    // Light impact
        case medium   // Medium impact
        case heavy    // Heavy impact
        case success  // Success notification
        case warning  // Warning notification
        case error    // Error notification
        case selection // Selection feedback
    }
    
    /// Singleton instance for easy access
    static let shared = HapticManager()
    
    // Private impact generators (reused for efficiency)
    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    private init() {
        // Pre-prepare the generators to reduce latency
        lightImpactGenerator.prepare()
        mediumImpactGenerator.prepare()
        heavyImpactGenerator.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }
    
    /// Trigger haptic feedback of the specified type
    /// - Parameter type: The type of haptic feedback to trigger
    func feedback(_ type: FeedbackType) {
        switch type {
        case .light:
            lightImpactGenerator.impactOccurred()
        case .medium:
            mediumImpactGenerator.impactOccurred()
        case .heavy:
            heavyImpactGenerator.impactOccurred()
        case .selection:
            selectionGenerator.selectionChanged()
        case .success:
            notificationGenerator.notificationOccurred(.success)
        case .warning:
            notificationGenerator.notificationOccurred(.warning)
        case .error:
            notificationGenerator.notificationOccurred(.error)
        }
    }
    
    /// Convenience method for medium impact feedback (most common)
    static func impact() {
        shared.feedback(.medium)
    }
    
    /// Convenience method for success notification feedback
    static func success() {
        shared.feedback(.success)
    }
    
    /// Convenience method for error notification feedback
    static func error() {
        shared.feedback(.error)
    }
    
    /// Convenience method for selection feedback
    static func selection() {
        shared.feedback(.selection)
    }
} 