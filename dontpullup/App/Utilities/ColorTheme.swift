import SwiftUI

struct DPUTheme {
    // Use Swift's built-in thread-safe singleton pattern
    private static let colorTheme = ColorTheme()
    
    static var colors: ColorTheme {
        return colorTheme
    }
    
    struct ColorTheme {
        // Primary colors
        let neonPurple = Color(red: 0.8, green: 0.2, blue: 0.8)
        let neonYellow = Color(red: 1.0, green: 0.8, blue: 0.0)
        let alertRed = Color(red: 1.0, green: 0.2, blue: 0.2)
        
        // Background colors
        let darkBlack = Color(red: 0.05, green: 0.05, blue: 0.05)
        let charcoalBlack = Color(red: 0.1, green: 0.1, blue: 0.1)
        
        // Text colors
        let lightGray = Color(red: 0.8, green: 0.8, blue: 0.8)
        
        init() {
            // Simple initialization, no risk of deadlock
        }
    }
}

// Usage example:
// Text("Hello").foregroundColor(DPUTheme.colors.neonPurple)
// Background: DPUTheme.colors.darkBlack