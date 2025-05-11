import SwiftUI
import MapKit
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

/// Minimalist incident type picker that appears after long press
struct IncidentPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MapViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Simple incident type options in a horizontal layout
            HStack(spacing: 25) {
                ForEach(IncidentType.allCases, id: \.self) { type in
                    Button {
                        // When incident type is selected:
                        // 1. Save the type to the draft
                        viewModel.reportDraft.incidentType = type
                        // 2. Dismiss this sheet
                        dismiss()
                        // 3. Present the photo picker (this is called from the parent view)
                    } label: {
                        VStack(spacing: 8) {
                            Text(type.emoji)
                                .font(.system(size: 50))
                            
                            Text(type.title)
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .frame(width: 90, height: 90)
                        .background(type.color.opacity(0.2))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.top, 30)
            
            Spacer()
        }
        .presentationDetents([.height(180)])
        .presentationBackground(.ultraThinMaterial)
    }
}

/// Minimal upload progress overlay that appears during video upload
struct UploadProgressView: View {
    @ObservedObject var viewModel: MapViewModel
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                // Non-intrusive upload progress indicator
                VStack(spacing: 8) {
                    ProgressView(value: viewModel.uploadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(width: 200)
                    
                    Text("Uploading video \(Int(viewModel.uploadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
                
                Spacer()
            }
            .padding(.bottom, 30)
        }
        .ignoresSafeArea()
    }
}

/// Extension for MapView to implement streamlined reporting flow
extension MapView {
    // This would be called from the Coordinator's handleLongPress method
    func handlePinDrop(at coordinate: CLLocationCoordinate2D) {
        viewModel.startReportFlow(at: coordinate)
        
        // Present the incident picker
        showIncidentPicker()
    }
    
    // Shows the incident picker sheet
    private func showIncidentPicker() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }
        
        let incidentPicker = UIHostingController(rootView: IncidentPickerView(viewModel: viewModel))
        incidentPicker.modalPresentationStyle = .formSheet
        
        rootVC.present(incidentPicker, animated: true)
        
        // Set up observation for when the incident type gets selected
        NotificationCenter.default.addObserver(forName: .incidentTypeSelected, object: nil, queue: .main) { _ in
            // Dismiss the incident picker first
            incidentPicker.dismiss(animated: true) {
                // Then show the photo picker
                self.showPhotoPicker()
            }
        }
    }
    
    // Shows the native photo picker immediately after incident selection
    private func showPhotoPicker() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .videos
        
        let picker = PHPickerViewController(configuration: config)
        
        // Use the Coordinator as the delegate instead of self
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let coordinator = (windowScene.windows.first?.rootViewController?.view as? MKMapView)?.delegate as? Coordinator {
            picker.delegate = coordinator
        } else {
            viewModel.showError("Could not setup photo picker")
            return
        }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }
        
        rootVC.present(picker, animated: true)
    }
}

// MARK: - Video Picking Implementation - Move to Coordinator class
extension Coordinator: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        // Dismiss picker immediately
        picker.dismiss(animated: true)
        
        // Handle video selection
        guard let result = results.first else {
            // User canceled selection, abort the flow
            parent.viewModel.reportStep = nil
            return
        }
        
        // Get the video URL from the result
        result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
            guard let url = url else {
                DispatchQueue.main.async {
                    self.parent.viewModel.showError("Could not load video")
                }
                return
            }
            
            // Check video duration (limit to 3 minutes)
            let asset = AVAsset(url: url)
            Task {
                do {
                    let duration = try await asset.load(.duration)
                    if duration.seconds > 180 { // 3 minutes
                        await MainActor.run {
                            self.parent.viewModel.showError("Video must be under 3 minutes")
                        }
                        return
                    }
                    
                    // Copy the video to a temporary location
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    
                    // Update the draft and start upload
                    await MainActor.run {
                        self.parent.viewModel.reportDraft.videoURL = tempURL
                        Task {
                            await self.parent.viewModel.upload(draft: self.parent.viewModel.reportDraft)
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.parent.viewModel.showError("Error processing video: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

// Custom notification for when incident type is selected
extension Notification.Name {
    static let incidentTypeSelected = Notification.Name("incidentTypeSelected")
} 
