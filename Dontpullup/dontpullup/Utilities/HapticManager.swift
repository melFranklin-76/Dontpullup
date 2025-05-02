import UIKit
import AudioToolbox

// Extension to add a contains method to UserDefaults
extension UserDefaults {
    func contains(key: String) -> Bool {
        return self.object(forKey: key) != nil
    }
}

/// A utility class to provide haptic feedback throughout the app
class HapticManager {
    
    // Define the UserDefaults key as a static constant to ensure consistency
    private static let hapticEnabledKey = "hapticFeedbackEnabled"
    
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
    
    /// Check if haptic feedback is enabled in user preferences
    static var isEnabled: Bool {
        // If the key doesn't exist yet, default to true
        if !UserDefaults.standard.contains(key: hapticEnabledKey) {
            print("HapticManager: hapticFeedbackEnabled not found in UserDefaults, setting default to true")
            UserDefaults.standard.set(true, forKey: hapticEnabledKey)
            // Force synchronize to ensure it's saved immediately
            UserDefaults.standard.synchronize()
            return true
        }
        let enabled = UserDefaults.standard.bool(forKey: hapticEnabledKey)
        print("HapticManager: Reading hapticFeedbackEnabled = \(enabled)")
        return enabled
    }
    
    /// Set the haptic feedback enabled state
    /// - Parameter enabled: Whether haptic feedback should be enabled
    static func setEnabled(_ enabled: Bool) {
        print("HapticManager: Setting hapticFeedbackEnabled to \(enabled)")
        UserDefaults.standard.set(enabled, forKey: hapticEnabledKey)
        // Force synchronize to ensure it's saved immediately
        UserDefaults.standard.synchronize()
    }
    
    /// Trigger haptic feedback of the specified type
    /// - Parameter type: The type of haptic feedback to trigger
    static func feedback(_ type: FeedbackType) {
        print("HapticManager - Triggering feedback: \(type)")
        
        // Check if haptic feedback is enabled
        guard isEnabled else {
            print("HapticManager - Feedback disabled in settings")
            return
        }
        
        print("HapticManager - Executing feedback: \(type)")
        
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
        
        // Check if haptic feedback is enabled
        guard isEnabled else {
            print("HapticManager - Feedback disabled in settings")
            return
        }
        
        print("HapticManager - Executing force feedback")
        
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
        // Check if haptic feedback is enabled
        guard isEnabled else {
            print("HapticManager - Feedback disabled in settings")
            return
        }
        
        print("HapticManager - Executing impact feedback")
        
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