import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation

// MARK: - Full Incident Type Picker

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
                        viewModel.reportDraft.incidentType = type
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
                // Use a longer delay to ensure the dismiss animation has completed
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    presentVideoPickerDirectly(for: type, viewModel: viewModel)
                    shouldPresentPicker = false
                }
            }
        }
    }
}

// MARK: - Minimalist Incident Picker

/// Reference to MinimalistIncidentPicker which is now in MinimalistIncidentPicker.swift

// MARK: - Shared Helper Functions for Video Picking

/// Helper function to present the video picker using UIKit
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
                
                // Much more reliable way to get a view controller that's DEFINITELY in the window hierarchy
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }),
                   let rootVC = keyWindow.rootViewController {
                    
                    // Get the topmost presented controller that can present another view controller
                    var topVC = rootVC
                    while let presented = topVC.presentedViewController {
                        // Skip alert controllers and already dismissing controllers
                        if presented is UIAlertController || presented.isBeingDismissed {
                            break
                        }
                        topVC = presented
                    }
                    
                    // Check if the view controller's view is actually in a window
                    if topVC.view.window != nil {
                        // Use a long delay to ensure any dismissals have completed
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            topVC.present(picker, animated: true)
                        }
                    } else {
                        // Fallback to rootVC if the topVC isn't in a window
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            rootVC.present(picker, animated: true)
                        }
                    }
                } else {
                    viewModel.showError("Could not present photo picker")
                }
                
            case .denied, .restricted:
                Task { @MainActor in
                    viewModel.showError("Please allow access to your photo library in Settings to upload videos")
                    // Open settings using SwiftUI's openURL environment value instead
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        // Completely replace the UIKit approach with this SwiftUI approach
                        let env = UIApplication.shared
                        env.open(settingsURL, options: [:], completionHandler: nil)
                    }
                }
                
            case .notDetermined:
                // This shouldn't happen since we just requested authorization
                Task { @MainActor in
                    viewModel.showError("Photo library access not determined")
                }
                
            @unknown default:
                Task { @MainActor in
                    viewModel.showError("Unknown photo library access status")
                }
            }
        }
    }
}

// MARK: - Video Delegate Adapter

/// Class for handling PHPicker delegates and processing video selections
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
            Task { @MainActor in
                self.viewModel.clearPendingData()
            }
            return
        }
        
        // Create a task to process the video in the background
        Task {
            if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                // Load the asset directly from the PHPickerResult 
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    let adapter = self
                    
                    // Get the asset identifier from the result
                    if let assetId = result.assetIdentifier {
                        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
                        if let asset = assets.firstObject {
                            // Use the new helper to process the video
                            Task {
                                await adapter.processPhotoPickerVideoResult(for: asset, continuation: continuation)
                            }
                            return
                        } else {
                            print("Error: Could not fetch PHAsset for assetIdentifier")
                            Task { @MainActor in
                                adapter.viewModel.showError("Could not fetch video asset")
                                adapter.viewModel.clearPendingData()
                            }
                            continuation.resume()
                            return
                        }
                    }
                    
                    // If we couldn't get the asset, resume immediately
                    continuation.resume()
                }
            } else {
                await MainActor.run {
                    self.viewModel.showError("The selected item is not a video")
                    self.viewModel.clearPendingData()
                }
            }
        }
    }
    
    // Helper method to handle asset loading from the item provider as fallback
    @MainActor
    private func loadAssetFromItemProvider(_ itemProvider: NSItemProvider, continuation: CheckedContinuation<Void, Never>) {
        // Request local identifier
        itemProvider.loadItem(forTypeIdentifier: UTType.movie.identifier, options: nil) { [weak self] (item, error) in
            guard let self = self else {
                continuation.resume()
                return
            }
            
            if let error = error {
                print("Failed to load item: \(error.localizedDescription)")
                // Must dispatch to MainActor since we're in a callback
                Task { @MainActor in 
                    self.viewModel.showError("Failed to load video: \(error.localizedDescription)")
                    self.viewModel.clearPendingData()
                }
                continuation.resume()
                return
            }
            
            if let url = item as? URL {
                // If we got a URL directly, try direct file access
                Task {
                    await self.processVideoFromURL(url, continuation: continuation)
                }
            } else if let videoData = item as? Data {
                // If we got data directly, process it
                Task {
                    await self.processVideoFromData(videoData, continuation: continuation)
                }
            } else {
                print("Failed to get video data or URL from item provider")
                // Must dispatch to MainActor since we're in a callback
                Task { @MainActor in
                    self.viewModel.showError("Could not access video data")
                    self.viewModel.clearPendingData()
                }
                continuation.resume()
            }
        }
    }
    
    // Helper method to handle video from URL
    @MainActor
    private func processVideoFromURL(_ sourceURL: URL, continuation: CheckedContinuation<Void, Never>) async {
        // Check if the file exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            print("File does not exist at path: \(sourceURL.path)")
            viewModel.showError("Video file not found at \(sourceURL.lastPathComponent)")
            viewModel.clearPendingData()
            continuation.resume()
            return
        }
        
        do {
            print("Processing video from URL: \(sourceURL.path)")
            if let attributes = try? fileManager.attributesOfItem(atPath: sourceURL.path),
               let fileSize = attributes[.size] {
                print("File size: \(fileSize)")
            }
            
            // Create a new temporary file using FileManager's preferred method
            let tempDir = fileManager.temporaryDirectory
            let tempURL = tempDir.appendingPathComponent("dpu_video_\(UUID().uuidString)").appendingPathExtension("mp4")
            
            // Try to directly copy first, if that fails, try the data method
            do {
                try fileManager.copyItem(at: sourceURL, to: tempURL)
            } catch {
                print("Direct file copy failed, trying data method: \(error.localizedDescription)")
                let videoData = try Data(contentsOf: sourceURL)
                print("Read \(videoData.count) bytes from source")
                try videoData.write(to: tempURL)
            }
            
            print("Successfully copied video to temp location: \(tempURL.path)")
            if let attributes = try? fileManager.attributesOfItem(atPath: tempURL.path),
               let fileSize = attributes[.size] {
                print("Temp file exists: \(fileManager.fileExists(atPath: tempURL.path))")
                print("Temp file size: \(fileSize)")
            }
            
            // Compress the video before upload
            let compressedURL = await StorageUploader.compressVideoIfNeeded(inputURL: tempURL)
            viewModel.reportDraft.videoURL = compressedURL
            
            // Upload the draft
            Task {
                print("Starting upload process for video at: \(compressedURL.path)")
                do {
                    // First add a file existence check that throws
                    if !FileManager.default.fileExists(atPath: compressedURL.path) {
                        throw NSError(domain: "IncidentPickers", code: 404, userInfo: [NSLocalizedDescriptionKey: "Video file not found"])
                    }
                    
                    print("Proceeding with upload")
                    await self.viewModel.upload(draft: self.viewModel.reportDraft)
                    print("Successfully uploaded video for pin")
                } catch {
                    print("Error during upload: \(error.localizedDescription)")
                    await MainActor.run {
                        self.viewModel.showError("Upload failed: \(error.localizedDescription)")
                    }
                }
            }
            
            continuation.resume()
        } catch {
            print("Error processing video from URL: \(error.localizedDescription)")
            viewModel.showError("Failed to process video: \(error.localizedDescription)")
            viewModel.clearPendingData()
            continuation.resume()
        }
    }
    
    // Helper method to handle video from Data
    @MainActor
    private func processVideoFromData(_ videoData: Data, continuation: CheckedContinuation<Void, Never>) async {
        print("Processing video from Data, size: \(videoData.count) bytes")
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("dpu_data_\(UUID().uuidString)").appendingPathExtension("mp4")
        do {
            if videoData.count == 0 {
                throw NSError(domain: "IncidentPickers", code: 400, userInfo: [NSLocalizedDescriptionKey: "Video data is empty (0 bytes)"])
            }
            try videoData.write(to: tempURL, options: .atomic)
            print("Successfully saved video data to temp location: \(tempURL.path)")
            if let attributes = try? fileManager.attributesOfItem(atPath: tempURL.path),
               let fileSize = attributes[.size], (fileSize as? Int == 0) {
                throw NSError(domain: "IncidentPickers", code: 400, userInfo: [NSLocalizedDescriptionKey: "Saved file has 0 bytes"])
            }
            
            // Compress the video before upload
            let compressedURL = await StorageUploader.compressVideoIfNeeded(inputURL: tempURL)
            self.viewModel.reportDraft.videoURL = compressedURL
            
            // Upload the draft
            Task {
                print("Starting upload process for video data at: \(compressedURL.path)")
                do {
                    if !FileManager.default.fileExists(atPath: compressedURL.path) {
                        throw NSError(domain: "IncidentPickers", code: 404, userInfo: [NSLocalizedDescriptionKey: "Video file not found"])
                    }
                    
                    print("Proceeding with upload")
                    await self.viewModel.upload(draft: self.viewModel.reportDraft)
                    print("Successfully uploaded video for pin")
                } catch {
                    print("Error during upload: \(error.localizedDescription)")
                    await MainActor.run {
                        self.viewModel.showError("Upload failed: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            print("Error processing video from data: \(error.localizedDescription)")
            viewModel.showError("Failed to save video data: \(error.localizedDescription)")
            viewModel.clearPendingData()
        }
        continuation.resume()
    }
    
    // Helper method to handle video from PHAsset
    @MainActor
    private func processVideoFromAsset(_ asset: PHAsset, continuation: CheckedContinuation<Void, Never>) async {
        print("Processing video from PHAsset")
        
        let options = PHVideoRequestOptions()
        options.version = .current
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        // Wrap PHImageManager call in a manually created Task to avoid closure issues
        var avAsset: AVAsset?
        
        // Create a simple completion handler
        let completion = { (asset: AVAsset?, audioMix: AVAudioMix?, info: [AnyHashable: Any]?) in
            avAsset = asset
        }
        
        // Get the asset request
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options, resultHandler: completion)
        
        // Wait for the completion handler to finish
        for _ in 0..<100 {
            if avAsset != nil { break }
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        // Check if we got an asset
        guard let urlAsset = avAsset as? AVURLAsset else {
            print("Error: Could not process video asset")
            viewModel.showError("Could not process video asset")
            viewModel.clearPendingData()
            continuation.resume()
            return
        }
        
        let tempURL = urlAsset.url
        print("Got video URL from asset: \(tempURL.path)")
        
        // Process as normal
        // Compress the video before upload
        let compressedURL = await StorageUploader.compressVideoIfNeeded(inputURL: tempURL)
        viewModel.reportDraft.videoURL = compressedURL
        
        // Create a draft pin at the current location
        if let coordinate = viewModel.userLocation?.coordinate {
            viewModel.reportDraft.coordinate = coordinate
            print("Created draft pin at \(coordinate.latitude), \(coordinate.longitude)")
        } else {
            print("Warning: No user location available for pin draft")
        }
        
        // Set the incident type from selection
        viewModel.reportDraft.incidentType = incidentType
        
        // Upload the draft
        Task {
            do {
                // First add a file existence check that throws
                if !FileManager.default.fileExists(atPath: compressedURL.path) {
                    throw NSError(domain: "IncidentPickers", code: 404, userInfo: [NSLocalizedDescriptionKey: "Video file not found"])
                }
                
                print("Proceeding with upload")
                await viewModel.upload(draft: viewModel.reportDraft)
                print("Successfully uploaded video for pin")
            } catch {
                print("Error during upload: \(error.localizedDescription)")
                // Already on MainActor in this case
                viewModel.showError("Upload failed: \(error.localizedDescription)")
            }
        }
        
        continuation.resume()
    }

    // Helper method to handle video from the picker
    @MainActor
    private func processPhotoPickerVideoResult(for asset: PHAsset, continuation: CheckedContinuation<Void, Never>) async {
        // Request the video data properly using PHAssetResourceManager
        print("Processing video from PHAsset: \(asset.localIdentifier)")
        
        let resources = PHAssetResource.assetResources(for: asset)
        guard let videoResource = resources.first(where: { $0.type == .video }) else {
            print("Error: No video resource found for the asset")
            viewModel.showError("Could not find video resource")
            viewModel.clearPendingData()
            continuation.resume()
            return
        }
        
        // Create a temporary file URL for the video
        let tempFileName = "dpu_video_\(UUID().uuidString).mp4"
        let tempFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(tempFileName)
        
        print("Preparing to export video to: \(tempFileURL.path)")
        
        // Replace semaphore with async/await pattern
        do {
            try await withCheckedThrowingContinuation { (completion: CheckedContinuation<Void, Error>) in
                PHAssetResourceManager.default().writeData(
                    for: videoResource, 
                    toFile: tempFileURL,
                    options: nil
                ) { error in
                    if let error = error {
                        completion.resume(throwing: error)
                    } else {
                        completion.resume()
                    }
                }
            }
        } catch {
            print("Error writing video to temp file: \(error.localizedDescription)")
            viewModel.showError("Could not access video: \(error.localizedDescription)")
            viewModel.clearPendingData()
            continuation.resume()
            return
        }
        
        // Now proceed with normal processing
        // Verify file exists and has content
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: tempFileURL.path) else {
            print("Error: Temp file does not exist at \(tempFileURL.path)")
            viewModel.showError("Video export failed")
            viewModel.clearPendingData()
            continuation.resume()
            return
        }
        
        // Check file size
        let attributes = try? fileManager.attributesOfItem(atPath: tempFileURL.path)
        let fileSize = attributes?[.size] as? UInt64 ?? 0
        print("Temp file exists: true, size: \(fileSize) bytes")
        
        if fileSize == 0 {
            print("Error: Exported video file is empty (0 bytes)")
            viewModel.showError("Video file is empty")
            viewModel.clearPendingData()
            try? fileManager.removeItem(at: tempFileURL) // Clean up
            continuation.resume()
            return
        }
        
        // Compress the video before upload
        let compressedURL = await StorageUploader.compressVideoIfNeeded(inputURL: tempFileURL)
        viewModel.reportDraft.videoURL = compressedURL
        
        // Create a draft pin at the current location
        if let coordinate = viewModel.userLocation?.coordinate {
            viewModel.reportDraft.coordinate = coordinate
            print("Created draft pin at \(coordinate.latitude), \(coordinate.longitude)")
        } else {
            print("Warning: No user location available for pin draft")
        }
        
        // Set the incident type from selection
        viewModel.reportDraft.incidentType = incidentType
        
        // Upload the draft
        Task {
            do {
                // File existence check
                if !FileManager.default.fileExists(atPath: compressedURL.path) {
                    throw NSError(domain: "IncidentPickers", code: 404, userInfo: [NSLocalizedDescriptionKey: "Video file not found"])
                }
                
                print("Proceeding with upload")
                await viewModel.upload(draft: viewModel.reportDraft)
                print("Successfully uploaded video for pin")
            } catch {
                print("Error during upload: \(error.localizedDescription)")
                // Already on MainActor in this case
                viewModel.showError("Upload failed: \(error.localizedDescription)")
            }
        }
        
        continuation.resume()
    }
} 
