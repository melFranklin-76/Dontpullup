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
    private static let shared = HapticManager()
    
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
    static func feedback(_ type: FeedbackType) {
        switch type {
        case .light:
            shared.lightImpactGenerator.impactOccurred()
        case .medium:
            shared.mediumImpactGenerator.impactOccurred()
        case .heavy:
            shared.heavyImpactGenerator.impactOccurred()
        case .selection:
            shared.selectionGenerator.selectionChanged()
        case .success:
            shared.notificationGenerator.notificationOccurred(.success)
        case .warning:
            shared.notificationGenerator.notificationOccurred(.warning)
        case .error:
            shared.notificationGenerator.notificationOccurred(.error)
        }
    }
    
    /// Convenience method for medium impact feedback (most common)
    static func impact() {
        feedback(.medium)
    }
    
    /// Convenience method for success notification feedback
    static func success() {
        feedback(.success)
    }
    
    /// Convenience method for error notification feedback
    static func error() {
        feedback(.error)
    }
    
    /// Convenience method for selection feedback
    static func selection() {
        feedback(.selection)
    }
} 