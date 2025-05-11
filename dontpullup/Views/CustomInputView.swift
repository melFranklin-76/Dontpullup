import SwiftUI
import UIKit

// MARK: - UIKit Helper for Input Assistant View

class CustomInputViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Disable built-in input assistant view to prevent constraint conflicts
        if let responders = self.view.subviews.first?.findInputAssistantView() {
            for responder in responders {
                responder.isHidden = true
                responder.removeFromSuperview()
            }
        }
    }
}

// UIView extension to find input assistant views
extension UIView {
    func findInputAssistantView() -> [UIView] {
        var results = [UIView]()
        
        for subview in subviews {
            if String(describing: type(of: subview)).contains("InputAssistant") {
                results.append(subview)
            } else {
                results.append(contentsOf: subview.findInputAssistantView())
            }
        }
        
        return results
    }
}

// MARK: - SwiftUI Wrapper

struct CustomInputViewWrapper<Content: View>: UIViewControllerRepresentable {
    let content: Content
    
    func makeUIViewController(context: Context) -> UIHostingController<Content> {
        let hostingController = InputFixHostingController(rootView: content)
        return hostingController
    }
    
    func updateUIViewController(_ uiViewController: UIHostingController<Content>, context: Context) {
        uiViewController.rootView = content
    }
}

// Custom hosting controller that disables the input assistant view
class InputFixHostingController<Content: View>: UIHostingController<Content> {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Apply the fix when the view loads
        fixInputAssistantHeight()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Apply it again when the view appears
        fixInputAssistantHeight()
    }
    
    private func fixInputAssistantHeight() {
        // Find and fix the height constraint of any input assistant views
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }
        
        for window in windowScene.windows {
            window.subviews.forEach { subview in
                if let assistantView = findInputAssistantView(in: subview) {
                    // Remove the fixed height constraint
                    for constraint in assistantView.constraints {
                        if constraint.identifier == "assistantHeight" {
                            assistantView.removeConstraint(constraint)
                        }
                    }
                    
                    // Add a flexible height constraint if needed
                    let flexibleConstraint = NSLayoutConstraint(
                        item: assistantView,
                        attribute: .height,
                        relatedBy: .greaterThanOrEqual,
                        toItem: nil,
                        attribute: .notAnAttribute,
                        multiplier: 1.0,
                        constant: 30
                    )
                    flexibleConstraint.priority = .defaultHigh
                    flexibleConstraint.identifier = "flexibleAssistantHeight"
                    assistantView.addConstraint(flexibleConstraint)
                }
            }
        }
    }
    
    private func findInputAssistantView(in view: UIView) -> UIView? {
        if String(describing: type(of: view)).contains("SystemInputAssistantView") {
            return view
        }
        
        for subview in view.subviews {
            if let found = findInputAssistantView(in: subview) {
                return found
            }
        }
        
        return nil
    }
}

// MARK: - View Extension for Easy Use

extension View {
    func fixInputAssistantHeight() -> some View {
        return CustomInputViewWrapper(content: self)
    }
} 