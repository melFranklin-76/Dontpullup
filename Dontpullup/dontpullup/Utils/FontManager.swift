import SwiftUI

class FontManager {
    static let shared = FontManager()
    private init() {}
}

// MARK: - Font Extensions
extension Font {
    static func titleFont(size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .default)
    }
    
    static func subtitleFont(size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .default)
    }
    
    static func bodyFont(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }
    
    static func captionFont(size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
} 