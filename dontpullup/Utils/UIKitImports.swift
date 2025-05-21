import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
public typealias UIPlatformView = UIView
public typealias UIPlatformColor = UIColor
public typealias UIPlatformImage = UIImage
public typealias UIPlatformDevice = UIDevice
#else
// Mac swiftUI imports for cross-platform code
import AppKit
public typealias UIPlatformView = NSView
public typealias UIPlatformColor = NSColor
public typealias UIPlatformImage = NSImage
public struct UIPlatformDevice {
    public static let current = UIPlatformDevice()
    public var identifierForVendor: UUID? {
        return UUID()
    }
}
#endif

/// Helper for cross-platform UIKit/AppKit compatibility
enum UIPlatformHelper {
    /// Checks if the current platform is iOS
    static var isIOS: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }
    
    /// Safely dismisses the keyboard on iOS
    static func dismissKeyboard() {
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), 
                                        to: nil, 
                                        from: nil, 
                                        for: nil)
        #endif
    }
    
    /// Determines if a text field is the current first responder
    static func isTextFieldActive() -> Bool {
        #if os(iOS)
        if let responder = UIResponder.currentFirstResponder,
           responder is UITextField || responder is UITextView {
            return true
        }
        #endif
        return false
    }
}

// MARK: - SwiftUI Extensions for Platform Compatibility

extension View {
    /// Adds a keyboard dismiss action on tap
    func dismissKeyboardOnTapGesture() -> some View {
        #if os(iOS)
        return self.onTapGesture {
            UIPlatformHelper.dismissKeyboard()
        }
        #else
        return self
        #endif
    }
    
    /// Adds a keyboard dismiss button to the keyboard toolbar
    func withKeyboardDismissButton() -> some View {
        #if os(iOS)
        return self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIPlatformHelper.dismissKeyboard()
                }
                .foregroundColor(.blue)
                .font(.headline)
            }
        }
        #else
        return self
        #endif
    }
} 