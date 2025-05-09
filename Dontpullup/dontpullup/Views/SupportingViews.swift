import SwiftUI

struct RectangleButtonStyle: ButtonStyle {
    var isSelected: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.red.opacity(0.75) : Color.black.opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct UploadProgressBar: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .cornerRadius(4)
                
                Rectangle()
                    .fill(Color.white)
                    .cornerRadius(4)
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: 8)
    }
}

struct TitleOverlay: View {
    var body: some View {
        ZStack {
            // Main "DON'T PULL UP" text
            Text("DON'T PULL UP")
                .font(.system(size: 36, weight: .black, design: .monospaced))
                .foregroundColor(Color(red: 1.0, green: 0, blue: 0))
                .shadow(color: .black.opacity(0.8), radius: 1, x: 2, y: 2)
                .overlay(
                    Text("DON'T PULL UP")
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .opacity(0.3)
                        .offset(x: 1, y: 1)
                )
            
            // Slanted "On Grandma" text
            Text("On Grandma")
                .font(.custom("Black Ops One", size: 28))
                .italic()
                .foregroundColor(DPUTheme.colors.alertRed)
                .shadow(color: .white.opacity(0.9), radius: 1, x: 1, y: 1)
                .rotationEffect(.degrees(-15))
                .offset(y: 8)
                .overlay(
                    Text("On Grandma")
                        .font(.custom("Black Ops One", size: 28))
                        .italic()
                        .foregroundColor(.white)
                        .opacity(0.3)
                        .rotationEffect(.degrees(-15))
                        .offset(x: 1, y: 9)
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 60)
    }
} 