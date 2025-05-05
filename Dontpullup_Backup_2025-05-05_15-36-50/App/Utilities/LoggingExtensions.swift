import Foundation
import UIKit

extension UIViewController {
    /// Log view controller lifecycle events with custom identifiers
    func logLifecycleEvent(_ event: String) {
        #if DEBUG
        print("ViewController[\(type(of: self))]: \(event)")
        #endif
    }
}

extension LoggingManager {
    /// Log constraint issues to help debug layout problems
    func logConstraintIssue(view: UIView, file: String = #file, line: Int = #line) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        print("⚠️ Constraint Issue: \(fileName):\(line)")
        print("View: \(type(of: view)), identifier: \(view.accessibilityIdentifier ?? "none")")
        print("Superviews: \(view.superview != nil ? String(describing: type(of: view.superview!)) : "none")")
        #endif
    }
    
    /// Create a symbolic breakpoint for constraint errors
    func setupConstraintDebugging() {
        print("To debug constraints, add a symbolic breakpoint at:")
        print("UIViewAlertForUnsatisfiableConstraints")
        print("with action: po [[UIWindow keyWindow] _autolayoutTrace]")
    }
}
