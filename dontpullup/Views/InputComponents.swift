import SwiftUI
import Foundation

// Import UIKit only on platforms where it's available
#if os(iOS)
import UIKit
#endif

/// Helper utilities for view styling and keyboard management
struct InputUtilities {
    
    /// Handle keyboard dismissal across platforms
    static func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), 
                                       to: nil, 
                                       from: nil, 
                                       for: nil)
        #endif
    }
    
    /// Check if we're on iOS
    static var isIOS: Bool {
        #if canImport(UIKit)
        return true
        #else
        return false
        #endif
    }
}

// MARK: - View Extensions

extension View {
    /// Fixes the input assistant height issues on iOS
    func fixInputAssistantHeight() -> some View {
        #if canImport(UIKit)
        return FixInputAssistantWrapper(content: self)
        #else
        return self // No-op on platforms without UIKit
        #endif
    }
    
    /// Adds a toolbar with a done button to dismiss the keyboard
    func addKeyboardDoneButton() -> some View {
        #if canImport(UIKit)
        return self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    InputUtilities.dismissKeyboard()
                }
                .foregroundColor(.blue)
                .font(.system(size: 18, weight: .semibold))
            }
        }
        #else
        return self
        #endif
    }
    
    /// Dismisses the keyboard when tapping outside of a text field
    func dismissKeyboardOnTap() -> some View {
        #if canImport(UIKit)
        return self.gesture(
            TapGesture()
                .onEnded { _ in
                    InputUtilities.dismissKeyboard()
                }
        )
        #else
        return self
        #endif
    }
}

// MARK: - Implementation for iOS

#if canImport(UIKit)

/// Wrapper for input assistant height fix
struct FixInputAssistantWrapper<Content: View>: UIViewControllerRepresentable {
    let content: Content
    
    func makeUIViewController(context: Context) -> UIHostingController<Content> {
        let controller = FixInputHostingController(rootView: content)
        // Apply fixes immediately
        DispatchQueue.main.async {
            controller.fixInputAssistantView()
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIHostingController<Content>, context: Context) {
        uiViewController.rootView = content
        
        // Re-apply fix after view updates
        if let fixController = uiViewController as? FixInputHostingController<Content> {
            DispatchQueue.main.async {
                fixController.fixInputAssistantView()
            }
        }
    }
}

/// Custom hosting controller to fix input assistant height issues
class FixInputHostingController<Content: View>: UIHostingController<Content> {
    override func viewDidLoad() {
        super.viewDidLoad()
        fixInputAssistantView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        fixInputAssistantView()
        
        // Add periodic check as views may be added dynamically
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.fixInputAssistantView()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        fixInputAssistantView()
        
        // Setup notification observer for keyboard appearance
        NotificationCenter.default.addObserver(self, 
                                              selector: #selector(keyboardWillShow),
                                              name: UIResponder.keyboardWillShowNotification,
                                              object: nil)
    }
    
    /// Called when keyboard will show
    @objc private func keyboardWillShow(notification: Notification) {
        // Apply fix with slight delay to ensure keyboard is fully visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.fixInputAssistantView()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Attempts to fix the input assistant view constraints
    func fixInputAssistantView() {
        #if os(iOS)
        if #available(iOS 15.0, *) {
            // Use the new API for iOS 15+
            for scene in UIApplication.shared.connectedScenes {
                if let windowScene = scene as? UIWindowScene {
                    for window in windowScene.windows {
                        findAndFixInputAssistantViews(in: window)
                    }
                }
            }
        } else {
            // Fallback for older iOS versions
            for window in UIApplication.shared.windows {
                findAndFixInputAssistantViews(in: window)
            }
        }
        #endif
    }
    
    /// Recursively searches for input assistant views and modifies their constraints
    private func findAndFixInputAssistantViews(in view: UIView) {
        let viewTypeName = String(describing: type(of: view))
        
        // Look for input assistant view or any views causing constraint conflicts
        if viewTypeName.contains("SystemInputAssistantView") || 
           viewTypeName.contains("InputAssistant") {
            
            // Remove ALL height constraints from this view
            var constraintsToRemove: [NSLayoutConstraint] = []
            
            for constraint in view.constraints where constraint.firstAttribute == .height {
                constraintsToRemove.append(constraint)
            }
            
            // Remove existing height constraints
            for constraint in constraintsToRemove {
                view.removeConstraint(constraint)
            }
            
            // Add a flexible height constraint
            let flexConstraint = NSLayoutConstraint(
                item: view,
                attribute: .height,
                relatedBy: .greaterThanOrEqual,
                toItem: nil,
                attribute: .notAnAttribute,
                multiplier: 1.0,
                constant: 10 // Minimum height
            )
            flexConstraint.priority = .defaultLow
            flexConstraint.identifier = "flexibleHeight_fixed"
            view.addConstraint(flexConstraint)
            
            // Force layout
            view.setNeedsLayout()
            view.layoutIfNeeded()
        }
        
        // Continue searching in subviews
        for subview in view.subviews {
            findAndFixInputAssistantViews(in: subview)
        }
    }
}
#endif 