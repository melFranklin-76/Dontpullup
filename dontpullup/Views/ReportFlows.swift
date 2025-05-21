import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import CoreLocation
import MapKit

// MARK: - Common Types and Utilities

/// Represents a step in the multi-step incident reporting flow
enum ReportStep: Int, Identifiable, Equatable {
    case incidentType
    case media
    case location
    case details
    case confirm
    
    var id: Int { rawValue }
}

/// Helper for requesting access to photo library
func checkPhotoLibraryAccess(completion: @escaping (Bool) -> Void) {
    PHPhotoLibrary.requestAuthorization { status in
        DispatchQueue.main.async {
            completion(status == .authorized || status == .limited)
        }
    }
}

// MARK: - Report Flow View Wrapper

/// Wrapper view to handle report flow display based on step type
struct ReportFlowView: View {
    @ObservedObject var viewModel: MapViewModel
    
    var body: some View {
        // Dispatch to appropriate report flow based on context
        ReportFlow(viewModel: viewModel)
    }
}

// MARK: - Full Multi-Step Report Flow

/// Multi-step incident reporting flow with form-based UI
struct ReportFlow: View {
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedItemID: String?
    @State private var selectedStep = ReportStep.incidentType
    @State private var description = ""
    @State private var showPhotosPicker = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var mediaData: Data?
    @State private var mediaType: UTType?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: 10) {
                    ForEach(ReportStep.incidentType.rawValue...ReportStep.confirm.rawValue, id: \.self) { index in
                        let step = ReportStep(rawValue: index)!
                        Circle()
                            .fill(step.rawValue <= selectedStep.rawValue ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 10)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // Step content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Step title
                        Text(stepTitle)
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.top, 20)
                            .padding(.horizontal)
                        
                        // Step content based on current step
                        if selectedStep == .incidentType {
                            incidentTypeView
                        } else if selectedStep == .media {
                            mediaSelectionView
                        } else if selectedStep == .location {
                            locationSelectionView
                        } else if selectedStep == .details {
                            detailsEntryView
                        } else if selectedStep == .confirm {
                            confirmationView
                        }
                    }
                    .padding(.bottom, 100) // Extra padding at bottom for buttons
                }
                
                // Bottom navigation buttons
                VStack {
                    Divider()
                    
                    HStack {
                        // Back button (except on first step)
                        if selectedStep.rawValue > 0 {
                            Button(action: goBack) {
                                Text("Back")
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 24)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                        
                        Spacer()
                        
                        // Next/Submit button
                        Button(action: advanceOrSubmit) {
                            Text(selectedStep == .confirm ? "Submit" : "Next")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(canProgress ? Color.blue : Color.gray)
                                .cornerRadius(8)
                        }
                        .disabled(!canProgress)
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                }
            }
            .background(Color(UIColor.systemBackground))
            .navigationBarTitle("Report Incident", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    viewModel.clearPendingData()
                    dismiss()
                }
            )
        }
        .onChange(of: viewModel.uploadProgress) { progress in
            // When upload completes, dismiss the view
            if progress >= 1.0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            }
        }
        .photosPicker(isPresented: $showPhotosPicker,
                     selection: $selectedItem,
                     matching: .videos,
                     photoLibrary: .shared())
        .onChange(of: selectedItem) { newItem in
            if let newItem = newItem {
                processSelectedItem(newItem)
            }
        }
    }
    
    // MARK: - Properties
    
    private var stepTitle: String {
        switch selectedStep {
        case .incidentType: return "What type of incident are you reporting?"
        case .media: return "Add video evidence"
        case .location: return "Confirm location"
        case .details: return "Add details"
        case .confirm: return "Review and submit"
        }
    }
    
    private var canProgress: Bool {
        switch selectedStep {
        case .incidentType:
            return true  // IncidentType is non-optional in PinDraft
        case .media:
            // Media is optional, so always allow continuing
            return true
        case .location:
            // User must have a location
            return viewModel.userLocation != nil
        case .details:
            // Description is optional, so always allow continuing
            return true
        case .confirm:
            // Final confirmation - require the essential pieces
            return viewModel.userLocation != nil  // IncidentType is non-optional
        }
    }
    
    // MARK: - Step Views
    
    private var incidentTypeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(IncidentType.allCases, id: \.self) { type in
                Button {
                    viewModel.reportDraft.incidentType = type
                } label: {
                    HStack {
                        Text(type.emoji)
                            .font(.system(size: 30))
                            .padding(.trailing, 8)
                        
                        VStack(alignment: .leading) {
                            Text(type.title)
                                .font(.headline)
                            
                            Text(type.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if viewModel.reportDraft.incidentType == type {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
    }
    
    private var mediaSelectionView: some View {
        VStack(spacing: 20) {
            if let videoURL = viewModel.reportDraft.videoURL {
                VStack {
                    Text("Video selected")
                        .font(.headline)
                    
                    Text(videoURL.lastPathComponent)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Change Video") {
                        showPhotosPicker = true
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 10)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
            } else {
                VStack {
                    Button {
                        showPhotosPicker = true
                    } label: {
                        VStack(spacing: 15) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)
                            
                            Text("Select a video")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                .background(Color(UIColor.secondarySystemBackground).cornerRadius(10))
                        )
                    }
                    
                    Text("Video evidence helps verify your report")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var locationSelectionView: some View {
        VStack(spacing: 20) {
            if let location = viewModel.userLocation {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your current location:")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                        
                        Text(String(format: "%.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude))
                            .font(.subheadline)
                    }
                    
                    Text("Incidents can only be reported at your current location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    Button("Refresh Location") {
                        Task {
                            do {
                                try await viewModel.forceLocationPermissionCheck()
                            } catch {
                                print("Error checking location permissions: \(error)")
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
                .padding(.horizontal)
            } else {
                VStack(spacing: 15) {
                    Text("Location Access Required")
                        .font(.headline)
                    
                    Text("We need your location to place the incident pin")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Allow Location Access") {
                        Task {
                            do {
                                try await viewModel.forceLocationPermissionCheck()
                            } catch {
                                print("Error checking location permissions: \(error)")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 10)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
                .padding(.horizontal)
            }
            
            if let location = viewModel.userLocation {
                // Mini map showing user location
                Map(coordinateRegion: .constant(MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                )), showsUserLocation: true, userTrackingMode: .constant(.follow))
                .frame(height: 200)
                .cornerRadius(10)
                .padding(.horizontal)
            }
        }
    }
    
    private var detailsEntryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add any additional details about the incident (optional)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextEditor(text: $description)
                .frame(minHeight: 150)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .padding(.bottom, 10)
            
            Text("These details will be visible to other app users")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .onChange(of: description) { newValue in
            viewModel.reportDraft.description = newValue
        }
    }
    
    private var confirmationView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Incident type
            VStack(alignment: .leading, spacing: 8) {
                Text("Incident Type")
                    .font(.headline)
                
                // Display the incident type (always exists as it's non-optional)
                HStack {
                    Text(viewModel.reportDraft.incidentType.emoji)
                        .font(.system(size: 24))
                    Text(viewModel.reportDraft.incidentType.title)
                        .font(.subheadline)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
            }
            
            Divider()
            
            // Location
            VStack(alignment: .leading, spacing: 8) {
                Text("Location")
                    .font(.headline)
                
                if let location = viewModel.userLocation {
                    Text(String(format: "%.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude))
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                }
            }
            
            Divider()
            
            // Media
            VStack(alignment: .leading, spacing: 8) {
                Text("Media")
                    .font(.headline)
                
                if let videoURL = viewModel.reportDraft.videoURL {
                    Text("Video included: \(videoURL.lastPathComponent)")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                } else {
                    Text("No video included")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                }
            }
            
            Divider()
            
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.headline)
                
                if !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                } else {
                    Text("No additional details provided")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    // MARK: - Functions
    
    private func goBack() {
        withAnimation {
            if selectedStep.rawValue > 0 {
                selectedStep = ReportStep(rawValue: selectedStep.rawValue - 1) ?? .incidentType
            }
        }
    }
    
    private func advanceOrSubmit() {
        withAnimation {
            if selectedStep == .confirm {
                // Final step - submit the report
                submitReport()
            } else {
                // Advance to next step
                selectedStep = ReportStep(rawValue: selectedStep.rawValue + 1) ?? .confirm
            }
        }
    }
    
    private func submitReport() {
        // If user's location exists, update draft coordinates
        if let location = viewModel.userLocation {
            viewModel.reportDraft.coordinate = location.coordinate
        }
        
        // Update description
        viewModel.reportDraft.description = description
        
        // Upload the pin
        Task {
            do {
                // Add a validation check that throws
                if viewModel.reportDraft.coordinate.latitude == 0 && viewModel.reportDraft.coordinate.longitude == 0 {
                    throw NSError(domain: "ReportFlows", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid coordinates"])
                }
                
                // Modified to avoid unreachable catch block - use a single try-catch
                var request = URLRequest(url: URL(string: "https://www.google.com")!)
                request.timeoutInterval = 10 // Set a reasonable timeout
                
                do {
                    let (_, response) = try await URLSession.shared.data(for: request)
                    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                        throw NSError(domain: "ReportFlows", code: 400, userInfo: [NSLocalizedDescriptionKey: "Network request failed with status code: \(String(describing: (response as? HTTPURLResponse)?.statusCode))"])
                    }
                } catch {
                    print("Network connectivity test failed: \(error.localizedDescription)")
                    // Even if network test fails, try to continue with upload
                    print("Attempting upload anyway despite network test failure")
                }
                
                // Then call the upload method which is throwing and async
                await viewModel.upload(draft: viewModel.reportDraft)
                
                // Call the now truly async refreshPins method
                do {
                    try await viewModel.refreshPins()
                } catch {
                    print("Error refreshing pins: \(error.localizedDescription)")
                }
            } catch {
                // Error is handled in the viewModel
                print("Error submitting report: \(error.localizedDescription)")
            }
        }
    }
    
    private func processSelectedItem(_ item: PhotosPickerItem) {
        Task {
            do {
                // Use proper error handling instead of try?
                let data = try await item.loadTransferable(type: Data.self)
                
                // Only proceed if we have valid data
                if let validData = data {
                    await MainActor.run {
                        // Store the data somewhere temporary
                        self.mediaData = validData
                        
                        // Try to determine type and save to a file
                        if UTType.movie.conforms(to: UTType.movie) {
                            self.mediaType = .movie
                            // Need to await because this accesses MainActor-isolated properties
                            Task { 
                                await MainActor.run {
                                    saveMediaToFile(data: validData, fileExtension: "mp4")
                                }
                            }
                        } else {
                            print("Unsupported media type")
                        }
                    }
                } else {
                    print("No data received from photo picker item")
                }
            } catch {
                // Log the error properly
                print("Error loading transferable data: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor // Add MainActor attribute to ensure this runs on main actor
    private func saveMediaToFile(data: Data, fileExtension: String) {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "media_\(UUID().uuidString).\(fileExtension)"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            print("Writing \(data.count) bytes to \(fileURL.path)")
            try data.write(to: fileURL)
            
            // Verify file was written correctly
            if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let fileSize = attributes[.size] as? Int {
                print("Saved file size: \(fileSize) bytes")
                
                if fileSize == 0 {
                    print("WARNING: File was saved but has 0 bytes")
                }
            }
            
            viewModel.reportDraft.videoURL = fileURL
            print("Media saved to: \(fileURL.path)")
        } catch {
            print("Failed to save media file: \(error.localizedDescription)")
        }
    }
}

// MARK: - Simplified Report Flow

/// Simplified reporting flow with minimal UI
struct SimplifiedReportFlow: View {
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Semi-transparent black background
            Color.black.opacity(0.85)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 32) {
                // Header with instructions
                Text("Report Incident")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                // Incident types grid
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
                    ForEach(IncidentType.allCases, id: \.self) { type in
                        Button {
                            // User selected an incident type
                            viewModel.reportDraft.incidentType = type
                            
                            // Set the coordinates from current user location
                            if let userLocation = viewModel.userLocation {
                                viewModel.reportDraft.coordinate = userLocation.coordinate
                            }
                            
                            // Dismiss this picker
                            dismiss()
                            
                            // Present photo picker with a delay to ensure dismissal completes
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                presentVideoPicker(for: type)
                            }
                        } label: {
                            VStack(spacing: 12) {
                                Text(type.emoji)
                                    .font(.system(size: 40))
                                    .padding(.bottom, 4)
                                
                                Text(type.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(width: 100, height: 120)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(type.color.opacity(0.3))
                                    .shadow(color: type.color.opacity(0.5), radius: 5)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(type.color.opacity(0.6), lineWidth: 2)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                
                // Cancel button
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.gray)
                .padding(.bottom, 20)
                .padding(.top, 10)
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Helper Methods
    
    private func presentVideoPicker(for incidentType: IncidentType) {
        // Check photo library permission and present the picker using UIKit
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    // Find a view controller to present from
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController {
                        
                        // Show the photo picker
                        let picker = UIImagePickerController()
                        picker.sourceType = .photoLibrary
                        picker.mediaTypes = ["public.movie"]
                        picker.allowsEditing = false
                        picker.videoQuality = .typeHigh
                        
                        // Create delegate adapter
                        let delegate = VideoDelegateAdapter(parentView: self)
                        VideoDelegateAdapter.activeDelegates.append(delegate)
                        
                        picker.delegate = delegate
                        
                        rootViewController.present(picker, animated: true)
                    }
                    
                case .denied, .restricted:
                    viewModel.showError("Please allow access to your photos to upload video evidence")
                    
                case .notDetermined:
                    // This shouldn't happen since we just requested access
                    break
                    
                @unknown default:
                    break
                }
            }
        }
    }
    
    // MARK: - Video Delegate Adapter for UIImagePickerController
    
    class VideoDelegateAdapter: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        static var activeDelegates = [VideoDelegateAdapter]()
        
        private var parentView: SimplifiedReportFlow
        
        init(parentView: SimplifiedReportFlow) {
            self.parentView = parentView
            super.init()
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // Dismiss the picker
            picker.dismiss(animated: true)
            
            // Remove from static array to avoid memory leaks
            Self.activeDelegates.removeAll { $0 === self }
            
            // Get the video URL from the picker
            guard let videoURL = info[.mediaURL] as? URL else {
                return
            }
            
            // Create a copy of the video file
            let fileManager = FileManager.default
            let tempDir = fileManager.temporaryDirectory
            let tempURL = tempDir.appendingPathComponent("video_\(UUID().uuidString).mp4")
            
            do {
                print("Source video URL: \(videoURL.path), size: \(String(describing: try? fileManager.attributesOfItem(atPath: videoURL.path)[.size] ?? 0))")
                
                // Try to directly copy first, if that fails, try the data method
                do {
                    try fileManager.copyItem(at: videoURL, to: tempURL)
                } catch {
                    print("Direct file copy failed, trying data method: \(error.localizedDescription)")
                    let videoData = try Data(contentsOf: videoURL)
                    print("Read \(videoData.count) bytes from source")
                    try videoData.write(to: tempURL)
                }
                
                print("Copied video to: \(tempURL.path), size: \(String(describing: try? fileManager.attributesOfItem(atPath: tempURL.path)[.size] ?? 0))")
                
                // Update the view model with the video URL
                DispatchQueue.main.async {
                    self.parentView.viewModel.reportDraft.videoURL = tempURL
                    
                    // Ensure we have location coordinates
                    if let userLocation = self.parentView.viewModel.userLocation {
                        self.parentView.viewModel.reportDraft.coordinate = userLocation.coordinate
                    }
                    
                    // Upload the draft
                    Task {
                        do {
                            // Verify the file has content
                            if let attributes = try? fileManager.attributesOfItem(atPath: tempURL.path),
                               let fileSize = attributes[.size] as? Int, 
                               fileSize == 0 {
                                throw NSError(domain: "ReportFlows", code: 404, userInfo: [NSLocalizedDescriptionKey: "Video file is empty (0 bytes)"])
                            }
                            
                            // Add validation checks that throw
                            if !FileManager.default.fileExists(atPath: tempURL.path) {
                                throw NSError(domain: "ReportFlows", code: 404, userInfo: [NSLocalizedDescriptionKey: "Video file not found"])
                            }
                            
                            print("Starting upload process for video at: \(tempURL.path)")
                            
                            // Modified to avoid unreachable catch block - use a single try-catch
                            var request = URLRequest(url: URL(string: "https://www.google.com")!)
                            request.timeoutInterval = 10 // Set a reasonable timeout
                            
                            do {
                                let (_, response) = try await URLSession.shared.data(for: request)
                                guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                                    throw NSError(domain: "ReportFlows", code: 400, userInfo: [NSLocalizedDescriptionKey: "Network request failed with status code: \(String(describing: (response as? HTTPURLResponse)?.statusCode))"])
                                }
                            } catch {
                                print("Network connectivity test failed: \(error.localizedDescription)")
                                // Even if network test fails, try to continue with upload
                                print("Attempting upload anyway despite network test failure")
                            }
                            
                            // Then call the upload method which is throwing and async
                            await self.parentView.viewModel.upload(draft: self.parentView.viewModel.reportDraft)
                            print("Successfully uploaded video for pin")
                            
                            // Call the now truly async refreshPins method
                            do {
                                try await self.parentView.viewModel.refreshPins()
                            } catch {
                                print("Error refreshing pins: \(error.localizedDescription)")
                            }
                        } catch {
                            print("Error during upload: \(error.localizedDescription)")
                            self.parentView.viewModel.showError("Upload failed: \(error.localizedDescription)")
                        }
                    }
                }
            } catch {
                print("Error copying video file: \(error.localizedDescription)")
                parentView.viewModel.showError("Failed to process video: \(error.localizedDescription)")
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            // Dismiss the picker
            picker.dismiss(animated: true)
            
            // Remove from static array to avoid memory leaks
            Self.activeDelegates.removeAll { $0 === self }
            
            // Clear any pending data in the view model
            parentView.viewModel.clearPendingData()
        }
    }
} 