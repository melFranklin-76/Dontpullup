import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct IncidentTypePicker: View {
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedType: IncidentType?
    @State private var shouldPresentPicker = false
    
    var body: some View {
        ZStack {
            // Background black with slight transparency
            Color.black.opacity(0.9)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                Text("Select Incident Type")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 24)
                
                ForEach(IncidentType.allCases, id: \.self) { type in
                    Button(action: {
                        selectedType = type
                        presentationMode.wrappedValue.dismiss()
                        shouldPresentPicker = true
                    }) {
                        HStack {
                            Text(type.emoji)
                                .font(.system(size: 36))
                            
                            VStack(alignment: .leading) {
                                Text(type.title)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text(type.description)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
                
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.red)
                .padding(.bottom, 32)
            }
            .padding(.horizontal)
        }
        .onChange(of: shouldPresentPicker) { newValue in
            if newValue, let type = selectedType {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    presentVideoPickerDirectly(for: type, viewModel: viewModel)
                    shouldPresentPicker = false
                }
            }
        }
    }
}

// Helper function to present the video picker using UIKit
@MainActor
func presentVideoPickerDirectly(for incidentType: IncidentType, viewModel: MapViewModel) {
    // First check photo library permission
    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
        DispatchQueue.main.async {
            switch status {
            case .authorized, .limited:
                // Configure and present picker
                var config = PHPickerConfiguration(photoLibrary: .shared())
                config.filter = .videos
                config.selectionLimit = 1
                
                let picker = PHPickerViewController(configuration: config)
                
                // Create the delegate adapter
                let delegateAdapter = VideoDelegateAdapter(incidentType: incidentType, viewModel: viewModel)
                VideoDelegateAdapter.activeDelegates.append(delegateAdapter)
                picker.delegate = delegateAdapter
                
                // Find the correct view controller to present from
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    
                    // Find the topmost presented controller
                    var topController = rootVC
                    while let presented = topController.presentedViewController {
                        topController = presented
                    }
                    
                    // Ensure we're on the main thread and add a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                        topController.present(picker, animated: true)
                    }
                } else {
                    viewModel.showError("Could not present photo picker")
                }
                
            case .denied, .restricted:
                viewModel.showError("Please allow access to your photo library in Settings to upload videos")
                // Optionally open settings
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
                
            case .notDetermined:
                // This shouldn't happen since we just requested authorization
                viewModel.showError("Photo library access not determined")
                
            @unknown default:
                viewModel.showError("Unknown photo library access status")
            }
        }
    }
}

// Helper class to handle async operations
@MainActor
class VideoProcessor {
    let viewModel: MapViewModel
    let incidentType: IncidentType
    
    init(viewModel: MapViewModel, incidentType: IncidentType) {
        self.viewModel = viewModel
        self.incidentType = incidentType
    }
    
    func processVideo(_ result: PHPickerResult) async {
        do {
            let url = try await loadMovie(from: result.itemProvider)
            
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
            
            do {
                try FileManager.default.copyItem(at: url, to: tempURL)
                try await viewModel.dropPinWithVideo(for: incidentType, videoURL: tempURL)
            } catch {
                viewModel.showError("Failed to process video: \(error.localizedDescription)")
                viewModel.clearPendingData()
                try? FileManager.default.removeItem(at: tempURL)
            }
        } catch {
            viewModel.showError("Failed to load video: \(error.localizedDescription)")
            viewModel.clearPendingData()
        }
    }
}

class VideoDelegateAdapter: NSObject, PHPickerViewControllerDelegate {
    // Static array to hold strong references to active delegates
    static var activeDelegates = [VideoDelegateAdapter]()
    
    let incidentType: IncidentType
    let viewModel: MapViewModel
    
    init(incidentType: IncidentType, viewModel: MapViewModel) {
        self.incidentType = incidentType
        self.viewModel = viewModel
        super.init()
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        // Immediately dismiss the picker since this needs to happen synchronously
        picker.dismiss(animated: true)
        
        // Remove this delegate from the static array to avoid memory leaks
        Self.activeDelegates.removeAll { $0 === self }
        
        guard let result = results.first else {
            // User canceled - clear any pending state safely on the main actor
            DispatchQueue.main.async { [self] in
                self.viewModel.clearPendingData()
            }
            return
        }
        
        // Create a continuation to bridge between sync and async
        let _ = Task {
            do {
                let url = try await loadMovie(from: result.itemProvider)
                
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
                
                do {
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    try await self.viewModel.dropPinWithVideo(for: self.incidentType, videoURL: tempURL)
                } catch {
                    await MainActor.run {
                        self.viewModel.showError("Failed to process video: \(error.localizedDescription)")
                        self.viewModel.clearPendingData()
                    }
                    try? FileManager.default.removeItem(at: tempURL)
                }
            } catch {
                await MainActor.run {
                    self.viewModel.showError("Failed to load video: \(error.localizedDescription)")
                    self.viewModel.clearPendingData()
                }
            }
        }
    }
}

// MARK: - Video loading (iOS 16+ uses async API directly)

// MARK: - ItemProvider Compatibility helper (bridges older callback API)

private func loadMovie(from provider: NSItemProvider) async throws -> URL {
    try await withCheckedThrowingContinuation { cont in
        _ = provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
            if let url {
                cont.resume(returning: url)
            } else {
                cont.resume(throwing: error ?? URLError(.cannotOpenFile))
            }
        }
    }
}
