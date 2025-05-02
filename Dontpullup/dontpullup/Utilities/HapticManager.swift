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
        print("HapticManager initialized")
    }
    
    /// Trigger haptic feedback of the specified type
    /// - Parameter type: The type of haptic feedback to trigger
    static func feedback(_ type: FeedbackType) {
        print("HapticManager - Triggering feedback: \(type)")
        
        // Create a local generator each time to ensure it works
        // This is less efficient but more reliable
        switch type {
        case .light:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
            // Also trigger on shared instance as backup
            shared.lightImpactGenerator.prepare()
            shared.lightImpactGenerator.impactOccurred()
            
        case .medium:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            // Also trigger on shared instance as backup
            shared.mediumImpactGenerator.prepare()
            shared.mediumImpactGenerator.impactOccurred()
            
        case .heavy:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
            // Also trigger on shared instance as backup
            shared.heavyImpactGenerator.prepare()
            shared.heavyImpactGenerator.impactOccurred()
            
        case .selection:
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
            // Also trigger on shared instance as backup
            shared.selectionGenerator.prepare()
            shared.selectionGenerator.selectionChanged()
            
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
            // Also trigger on shared instance as backup
            shared.notificationGenerator.prepare()
            shared.notificationGenerator.notificationOccurred(.success)
            
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)
            // Also trigger on shared instance as backup
            shared.notificationGenerator.prepare()
            shared.notificationGenerator.notificationOccurred(.warning)
            
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
            // Also trigger on shared instance as backup
            shared.notificationGenerator.prepare()
            shared.notificationGenerator.notificationOccurred(.error)
        }
    }
    
    /// Force feedback with intensity levels
    /// Used when you need a stronger, more noticeable feedback
    static func forceFeedback() {
        print("HapticManager - Force feedback triggered")
        
        // Create a sequence of haptics for a stronger effect
        let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
        heavyGenerator.prepare()
        heavyGenerator.impactOccurred(intensity: 1.0)
        
        // Delay slightly between impacts for maximum effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
            mediumGenerator.prepare()
            mediumGenerator.impactOccurred(intensity: 1.0)
        }
    }
    
    /// Convenience method for medium impact feedback (most common)
    static func impact() {
        print("HapticManager.impact() called")
        feedback(.medium)
    }
    
    /// Convenience method for success notification feedback
    static func success() {
        print("HapticManager.success() called")
        feedback(.success)
    }
    
    /// Convenience method for error notification feedback
    static func error() {
        print("HapticManager.error() called")
        feedback(.error)
    }
    
    /// Convenience method for selection feedback
    static func selection() {
        print("HapticManager.selection() called")
        feedback(.selection)
    }
} 