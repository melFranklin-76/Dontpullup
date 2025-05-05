import SwiftUI
import MapKit

// Remove the duplicate extension to fix the compilation error
// The withMapStyle() extension is already defined in dontpullupApp.swift

struct SplashScreen: View {
    @EnvironmentObject private var authState: AuthState
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @State private var scale = 0.7
    @State private var opacity = 0.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack { // Background ZStack
                // Background Image
                Image("welcome_background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
                
                // Semi-transparent overlay
                Color.black.opacity(0.7)
                    .edgesIgnoringSafeArea(.all)
                
                // Original ZStack content
                ZStack {
                    // Only show splash content, controlled by RootView's isLoading
                    SplashContent()
                        .scaleEffect(scale)
                        .opacity(opacity)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Keep onAppear logic for animation
            // RootView controls isLoading, so we don't set it here
            withAnimation(.easeOut(duration: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

// Helper Views
private struct SplashContent: View {
    // Create a computed property to get the app icon
    private var appIcon: UIImage? {
        // Try different sizes, starting with the largest
        let iconNames = ["1024 1", "180", "167 3", "152", "120", "76"]
        for name in iconNames {
            if let image = UIImage(named: name) {
                return image
            }
        }
        return nil
    }
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            
            VStack(spacing: size * 0.05) {
                Group {
                    if let icon = appIcon {
                        Image(uiImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                    } else {
                        // Fallback to a system icon if app icon is not found
 let image = UIImage(named: name) {
                return image
            }
        }
        return nil
    }
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            
            VStack(spacing: size * 0.05) {
                Group {
                    if let icon = appIcon {
                        Image(uiImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                    } else {
                        // Fallback to a system icon if app icon is not found
                        Image(systemName: "map.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(.red)
                    }
                }
                .frame(width: size * 0.4, height: size * 0.4)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .white.opacity(0.3), radius: 10)
                
                Text("Don't Pull Up")
                    .font(.system(size: size * 0.08, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}

// Renamed to avoid conflict
private struct SplashLoadingView: View {
    var body: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
    }
} 