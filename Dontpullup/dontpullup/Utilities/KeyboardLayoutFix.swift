import UIKit

/// Extension to fix common keyboard input assistant view constraint issues
extension UIViewController {
    /// Call this method in viewDidLoad to prevent constraint conflicts with SystemInputAssistantView
    @objc func fixKeyboardInputAssistantConstraints() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(adjustInputAssistantViewIfNeeded),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
    }
    
    @objc private func adjustInputAssistantViewIfNeeded() {
        // Find and fix any SystemInputAssistantView that might cause constraint conflicts
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }),
               let keyboardHost = keyWindow.subviews.first(where: { String(describing: type(of: $0)).contains("InputSetHostView") }) {
                
                // Look for the input assistant view
                for subview in keyboardHost.subviews {
                    if String(describing: type(of: subview)).contains("SystemInputAssistantView") {
                        // Remove the conflicting height constraint
                        for constraint in subview.constraints {
                            if constraint.identifier == "assistantHeight" {
                                constraint.isActive = false
                                break
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Prevents potential memory leaks
    @objc func removeKeyboardConstraintObservers() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
    }
} 