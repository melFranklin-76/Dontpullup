import SwiftUI

/// Minimal upload progress overlay that appears during video upload
struct UploadProgressOverlay: View {
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        // Only show when actively uploading (progress > 0 and < 1)
        if viewModel.uploadProgress > 0 && viewModel.uploadProgress < 1.0 {
            VStack {
                Spacer()
                
                // Floating progress indicator at bottom of screen
                HStack(spacing: 12) {
                    // Progress circular indicator
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                            .frame(width: 30, height: 30)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(viewModel.uploadProgress))
                            .stroke(Color.red, lineWidth: 3)
                            .frame(width: 30, height: 30)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(Int(viewModel.uploadProgress * 100))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Text("Uploading video...")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(colorScheme == .dark ? 
                              Color.black.opacity(0.8) : 
                              Color.gray.opacity(0.8))
                        .shadow(color: Color.black.opacity(0.3), radius: 5)
                )
                .padding(.bottom, 30)
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: viewModel.uploadProgress)
        }
    }
}

// MARK: - Previews
struct UploadProgressOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            let viewModel = MapViewModel(authState: AuthState.shared)
            UploadProgressOverlay(viewModel: viewModel)
                .onAppear {
                    viewModel.uploadProgress = 0.67
                }
        }
    }
} 