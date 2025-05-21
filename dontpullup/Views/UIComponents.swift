import SwiftUI

// MARK: - Button Styles

/// Rectangle button style with selection state
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

/// Scale animation button style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .brightness(configuration.isPressed ? 0.1 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Incident Filter Components

struct IncidentFilterButtons: View {
    @ObservedObject var viewModel: MapViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            FilterButton(type: .verbal, isSelected: viewModel.selectedFilters.contains(.verbal)) {
                viewModel.toggleFilter(.verbal)
            }
            
            FilterButton(type: .physical, isSelected: viewModel.selectedFilters.contains(.physical)) {
                viewModel.toggleFilter(.physical)
            }
            
            FilterButton(type: .emergency, isSelected: viewModel.selectedFilters.contains(.emergency)) {
                viewModel.toggleFilter(.emergency)
            }
        }
        .padding(.vertical, 8)
    }
}

struct FilterButton: View {
    let type: IncidentType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(type.emoji)
                .font(.system(size: 24))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(RectangleButtonStyle(isSelected: isSelected))
    }
}

// MARK: - Progress Indicators

/// Minimal upload progress overlay that appears during video upload
struct UploadProgressOverlay: View {
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.colorScheme) var colorScheme
    
    // Compute a safe progress value that will never be NaN
    private var safeProgress: CGFloat {
        let rawValue = viewModel.uploadProgress
        // Ensure value is between 0 and 1, and is not NaN
        if rawValue.isNaN || rawValue < 0 {
            return 0
        } else if rawValue > 1 {
            return 1
        }
        return CGFloat(rawValue)
    }
    
    // Compute a safe percent display value
    private var progressPercent: Int {
        let value = Int(safeProgress * 100)
        // Further validation to ensure we have a valid integer
        return max(0, min(100, value))
    }
    
    var body: some View {
        // Only show when actively uploading (progress > 0 and < 1)
        if safeProgress > 0 && safeProgress < 1.0 {
            VStack {
                Spacer()
                // Centered progress indicator (original size)
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                            .frame(width: 30, height: 30)
                        Circle()
                            .trim(from: 0, to: safeProgress)
                            .stroke(Color.red, lineWidth: 3)
                            .frame(width: 30, height: 30)
                            .rotationEffect(.degrees(-90))
                        Text("\(progressPercent)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text("Uploading video...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
                .background(
                    Capsule()
                        .fill(colorScheme == .dark ? 
                              Color.black.opacity(0.8) : 
                              Color.gray.opacity(0.8))
                        .shadow(color: Color.black.opacity(0.3), radius: 5)
                )
                Spacer()
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: viewModel.uploadProgress)
        }
    }
}

// MARK: - Map Content Wrapper
struct MapContentWrapper: View {
    @ObservedObject var viewModel: MapViewModel
    
    var body: some View {
        ZStack {
            // Main MapView
            MapView(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)
            
            // Upload progress overlay
            if viewModel.uploadProgress > 0 && viewModel.uploadProgress < 1.0 {
                UploadProgressOverlay(viewModel: viewModel)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.uploadProgress)
            }
        }
    }
} 