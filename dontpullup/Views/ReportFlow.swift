import SwiftUI
import AVKit
import MapKit

/// Main container view that manages the three-step reporting flow
struct ReportFlowView: View {
    @ObservedObject var viewModel: MapViewModel
    @State private var isRecording = false
    @State private var recorder: AVCaptureSession?
    @State private var videoURL: URL?
    @State private var recordingDuration: TimeInterval = 0
    @State private var showCamera = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Title with step indicator
                HStack {
                    Text("Report Incident")
                        .font(.headline)
                    
                    Spacer()
                    
                    // Step indicators (1-2-3)
                    HStack(spacing: 4) {
                        ForEach(ReportStep.allCases, id: \.self) { step in
                            Circle()
                                .fill(viewModel.reportStep == step ? DPUTheme.colors.alertRed : Color.gray)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .padding()
                
                // Dynamic content based on current step
                if let currentStep = viewModel.reportStep {
                    switch currentStep {
                    case .type:
                        IncidentTypeSelectionView(viewModel: viewModel)
                    case .video:
                        VideoRecordingView(
                            viewModel: viewModel,
                            isRecording: $isRecording,
                            recorder: $recorder,
                            videoURL: $videoURL,
                            recordingDuration: $recordingDuration,
                            showCamera: $showCamera
                        )
                    case .confirm:
                        ConfirmReportView(viewModel: viewModel)
                    }
                }
                
                Spacer()
                
                // Navigation buttons
                HStack {
                    Button("Cancel") {
                        viewModel.reportStep = nil
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    Spacer()
                    
                    if let currentStep = viewModel.reportStep {
                        // Next/Back buttons based on current step
                        switch currentStep {
                        case .type:
                            Button("Next") {
                                viewModel.reportStep = .video
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            // We're using a default value in PinDraft init so this is always valid
                            
                        case .video:
                            HStack {
                                Button("Back") {
                                    viewModel.reportStep = .type
                                }
                                .buttonStyle(SecondaryButtonStyle())
                                
                                Button("Next") {
                                    viewModel.reportStep = .confirm
                                }
                                .buttonStyle(PrimaryButtonStyle())
                                // No need to disable - can always proceed with or without video
                            }
                            
                        case .confirm:
                            HStack {
                                Button("Back") {
                                    viewModel.reportStep = .video
                                }
                                .buttonStyle(SecondaryButtonStyle())
                                
                                Button("Submit") {
                                    Task {
                                        // Update video URL in draft
                                        viewModel.reportDraft.videoURL = videoURL
                                        await viewModel.upload(draft: viewModel.reportDraft)
                                    }
                                }
                                .buttonStyle(PrimaryButtonStyle())
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarHidden(true)
            .background(DPUTheme.colors.darkBlack)
            .foregroundColor(DPUTheme.colors.lightGray)
        }
        .preferredColorScheme(.dark)
    }
}

/// Step 1: Select incident type
struct IncidentTypeSelectionView: View {
    @ObservedObject var viewModel: MapViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("What type of incident would you like to report?")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Incident type options
            ForEach(IncidentType.allCases, id: \.self) { type in
                Button(action: {
                    viewModel.reportDraft.incidentType = type
                }) {
                    HStack {
                        Text(type.emoji)
                            .font(.title)
                        
                        VStack(alignment: .leading) {
                            Text(type.title)
                                .font(.headline)
                            Text(type.description)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        if viewModel.reportDraft.incidentType == type {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(viewModel.reportDraft.incidentType == type ? type.color : Color.gray, lineWidth: 2)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
        }
        .padding()
    }
}

/// Step 2: Record video or skip
struct VideoRecordingView: View {
    @ObservedObject var viewModel: MapViewModel
    @Binding var isRecording: Bool
    @Binding var recorder: AVCaptureSession?
    @Binding var videoURL: URL?
    @Binding var recordingDuration: TimeInterval
    @Binding var showCamera: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Include a video with your report?")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // No video option
            VStack(spacing: 12) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("No video")
                    .font(.title3)
                    .foregroundColor(.gray)
                
                Text("Continue with location only")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray, lineWidth: 1)
            )
            .padding(.horizontal)
            .onTapGesture {
                // Clear any video URL
                videoURL = nil
            }
            
            Divider()
                .padding(.vertical)
            
            // Use existing video
            VStack(spacing: 12) {
                Image(systemName: "video.fill")
                    .font(.system(size: 60))
                    .foregroundColor(viewModel.authState.isAnonymous ? .gray : .blue)
                
                Text("Select existing video")
                    .font(.title3)
                    .foregroundColor(viewModel.authState.isAnonymous ? .gray : .blue)
                
                Text("Choose a video from your library")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if viewModel.authState.isAnonymous {
                    Text("Video upload disabled for guests")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(viewModel.authState.isAnonymous ? Color.gray : Color.blue, lineWidth: 1)
            )
            .padding(.horizontal)
            .onTapGesture {
                if viewModel.authState.isAnonymous {
                    viewModel.showError("Guests cannot upload videos.")
                } else {
                    // Simulate selecting a video
                    // TODO: Implement actual video picker logic here
                    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    videoURL = documentsPath.appendingPathComponent("selected_video.mp4")
                }
            }
            
            Spacer()
            
            // Note about video selection
            if videoURL != nil {
                Text("Video selected")
                    .foregroundColor(.green)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.1))
                    )
            }
        }
        .padding()
    }
}

/// Step 3: Confirm and submit report
struct ConfirmReportView: View {
    @ObservedObject var viewModel: MapViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Confirm Your Report")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Incident Type:")
                        .fontWeight(.semibold)
                    
                    Text("\(viewModel.reportDraft.incidentType.emoji) \(viewModel.reportDraft.incidentType.title)")
                }
                
                HStack {
                    Text("Location:")
                        .fontWeight(.semibold)
                    
                    let coord = viewModel.reportDraft.coordinate
                    Text(String(format: "%.5f, %.5f", coord.latitude, coord.longitude))
                        .font(.system(.subheadline, design: .monospaced))
                }
                
                HStack {
                    Text("Video:")
                        .fontWeight(.semibold)
                    
                    if viewModel.reportDraft.videoURL != nil {
                        Text("Included")
                            .foregroundColor(.green)
                    } else {
                        Text("None")
                            .foregroundColor(.gray)
                    }
                }
                
                // Mini map
                ZStack {
                    Color(.systemGray6)
                        .frame(height: 150)
                        .cornerRadius(12)
                    
                    Text("Location Preview")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray, lineWidth: 1)
            )
            
            if viewModel.uploadProgress > 0 {
                VStack(spacing: 8) {
                    ProgressView(value: viewModel.uploadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    Text("\(Int(viewModel.uploadProgress * 100))% Uploaded")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(DPUTheme.colors.alertRed)
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.gray.opacity(0.2))
            .foregroundColor(DPUTheme.colors.lightGray)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

// MARK: - Preview
struct ReportFlowView_Previews: PreviewProvider {
    static var previews: some View {
        ReportFlowView(viewModel: MapViewModel(authState: AuthState.shared))
    }
} 