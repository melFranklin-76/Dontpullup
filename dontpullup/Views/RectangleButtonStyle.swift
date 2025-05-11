import SwiftUI

struct RectangleButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(isSelected ? Color.blue.opacity(0.8) : Color.gray.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
            .shadow(color: isSelected ? .blue.opacity(0.3) : .clear, radius: 5)
    }
} 