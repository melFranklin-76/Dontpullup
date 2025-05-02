import UIKit
import AudioToolbox

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
    
    // Using AudioServicesPlaySystemSound is a more reliable way to trigger haptics and sounds
    private static let systemSoundID: UInt32 = 1519 // Default haptic feedback sound ID
    private static let heavyFeedbackID: UInt32 = 1520
    private static let mediumFeedbackID: UInt32 = 1521
    private static let errorFeedbackID: UInt32 = 1107
    private static let successFeedbackID: UInt32 = 1521
    
    private static let selectFeedbackID: UInt32 = 1519
    
    // Backup UIFeedbackGenerator instances for devices that support them
    private static let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    /// Trigger haptic feedback of the specified type
    /// - Parameter type: The type of haptic feedback to trigger
    static func feedback(_ type: FeedbackType) {
        print("HapticManager - Triggering feedback: \(type)")
        
        // Try direct system sound approach first - this should work on all devices
        switch type {
        case .light:
            AudioServicesPlaySystemSound(1519)
        case .medium:
            AudioServicesPlaySystemSound(1520)
        case .heavy:
            // For heavy feedback, play multiple sounds with vibration
            AudioServicesPlaySystemSound(1521)
            // Also try to trigger the device to vibrate
            AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
        case .selection:
            AudioServicesPlaySystemSound(1519)
        case .success:
            AudioServicesPlaySystemSound(1521)
        case .warning:
            AudioServicesPlaySystemSound(1107)
        case .error:
            // For error, use the vibrate alert
            AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
        }
        
        // As a backup, also try the UIFeedbackGenerator
        impactGenerator.prepare()
        impactGenerator.impactOccurred(intensity: 1.0)
    }
    
    /// Force feedback with vibration
    /// This uses the system vibrate function which should work on all iPhones
    static func forceFeedback() {
        print("HapticManager - Force vibration triggered")
        
        // This is a direct vibration command that should work on all phones
        AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
        
        // Try a second approach after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred(intensity: 1.0)
            
            // Add a third approach for good measure
            AudioServicesPlaySystemSound(1521)
        }
    }
    
    /// Convenience method for medium impact feedback (most common)
    static func impact() {
        print("HapticManager.impact() called")
        // Use direct vibration for more reliability
        AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
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