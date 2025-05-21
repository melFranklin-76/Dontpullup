import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation

// MARK: - Button Styles

// Using ScaleButtonStyle from UIComponents.swift

// MARK: - Minimalist Incident Picker

/// Minimalist incident type picker shown immediately after long-press
struct MinimalistIncidentPicker: View {
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // Haptic feedback
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with instructions
            Text("Select Incident Type")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top, 16)
            
            // Incident type buttons
            HStack(spacing: 25) {
                ForEach(IncidentType.allCases, id: \.self) { type in
                    Button {
                        // Provide haptic feedback
                        hapticFeedback.impactOccurred()
                        
                        // User selected an incident type
                        viewModel.reportDraft.incidentType = type
                        
                        // Dismiss this picker
                        dismiss()
                        
                        // Present photo picker next with a longer delay
                        // to ensure dismissal completes first
                        Task { @MainActor in
                            // Longer delay to allow dismissal to complete - use proper async operation instead of try? await
                            let _ = try await URLSession.shared.data(for: URLRequest(url: URL(string: "about:blank")!), delegate: nil)
                            presentPhotoPicker(for: type)
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Text(type.emoji)
                                .font(.system(size: 40))
                                .shadow(color: .black.opacity(0.5), radius: 2)
                            
                            Text(type.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(width: 80, height: 90)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(type.color.opacity(0.3))
                                .shadow(color: type.color.opacity(0.5), radius: 5)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(type.color.opacity(0.8), lineWidth: 2)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle()) // Custom button style with animation
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 15)
            
            // Optional cancel button
            Button("Cancel") {
                // Provide haptic feedback
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            }
            .foregroundColor(.gray)
            .padding(.bottom, 12)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(colorScheme == .dark ? 
                      Color.black.opacity(0.9) : 
                      Color.black.opacity(0.8))
                .shadow(color: Color.black.opacity(0.4), radius: 20)
        )
        // Force a small size presentation that fits just the buttons
        .presentationDetents([.height(220)])
        .presentationBackground(Material.ultraThinMaterial)
    }
    
    // Presents the photo picker directly after selecting incident type
    private func presentPhotoPicker(for incidentType: IncidentType) {
        // Use a longer delay to ensure dismiss animation has completed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Use the improved version that guarantees presentation from a valid view controller
            presentVideoPickerDirectly(for: incidentType, viewModel: viewModel)
        }
    }
}

// MARK: - Simplified Incident Type Picker

/// Simple incident type picker shown in a sheet
struct SimplifiedIncidentPicker: View {
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
    
    private func presentVideoPicker(for incidentType: IncidentType) {
        // Check photo library permission and present the picker using UIKit
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    // Use the shared helper for a consistent implementation
                    presentVideoPickerDirectly(for: incidentType, viewModel: viewModel)
                    
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
}

// MARK: - Custom Notification Name

/// Custom notification for when incident type is selected
extension Notification.Name {
    static let incidentTypeSelected = Notification.Name("incidentTypeSelected")
} 