import SwiftUI
import MapKit

/// MapView wrapper that includes the upload progress indicator
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

// Removed duplicate UploadProgressOverlay definition - now using the one from UploadProgressOverlay.swift 