import SwiftUI

/// Detailed instructions view showing all app functions with step-by-step guidance
struct DetailedInstructionsView: View {
    // To dismiss the view
    @Environment(\.dismiss) var dismiss
    
    // Track which section is expanded
    @State private var expandedSection: InstructionSection? = .mapInteraction
    
    // Categories of instructions
    enum InstructionSection: String, Identifiable, CaseIterable {
        case mapInteraction = "Map Navigation"
        case pins = "Pin Management"
        case incidents = "Reporting Incidents"
        case videos = "Video Functions"
        case account = "Account Settings"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .mapInteraction: return "map"
            case .pins: return "mappin.and.ellipse"
            case .incidents: return "exclamationmark.triangle"
            case .videos: return "video.fill"
            case .account: return "person.crop.circle"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Overlay for tap to dismiss - covers entire screen
            Color.black.opacity(0.001) // Nearly transparent
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    dismiss()
                }
            
            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    Text("Instructions 📝")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                Text("Tap a section to expand")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.bottom, 5)
                
                // Scrollable content
                ScrollView {
                    VStack(spacing: 15) {
                        // Map navigation instructions
                        instructionSection(section: .mapInteraction) {
                            InstructionItem(title: "Moving the Map 👆", steps: [
                                "Drag with one finger to move the map in any direction",
                                "Pinch with two fingers to zoom in and out",
                                "Double-tap with one finger to zoom in slightly"
                            ])
                            
                            InstructionItem(title: "Center Your Location 📍", steps: [
                                "Tap the location button (📍) at the bottom of the screen",
                                "The map will center on your current location",
                                "The map will zoom to show a 200-foot radius around you"
                            ])
                            
                            InstructionItem(title: "Change Map Type 🗺️", steps: [
                                "Tap the map type button at the bottom of the screen",
                                "Cycles between standard and satellite view"
                            ])
                            
                            InstructionItem(title: "Zoom Controls ➕➖", steps: [
                                "Tap + button on the right side to zoom in",
                                "Tap - button on the right side to zoom out",
                                "You can also pinch the screen to zoom"
                            ])
                        }
                        
                        // Pin management instructions
                        instructionSection(section: .pins) {
                            InstructionItem(title: "View Your Pins 📱", steps: [
                                "Tap the phone icon (📱) on the right side of the screen",
                                "The map will filter to show only pins you created",
                                "Tap the phone icon again to see all pins"
                            ])
                            
                            InstructionItem(title: "Filter Pins By Type", steps: [
                                "Tap the verbal icon (🗣️) to toggle verbal incidents",
                                "Tap the physical icon (👊) to toggle physical incidents",
                                "Tap the emergency icon (🚨) to toggle emergency incidents",
                                "Multiple filters can be active at once"
                            ])
                            
                            InstructionItem(title: "Delete Your Pins ✏️", steps: [
                                "Tap the pencil icon (✏️) at the bottom to enter edit mode",
                                "Tap on any of your pins to delete them",
                                "Tap the X button to exit edit mode when finished",
                                "Note: You can only delete pins you created"
                            ])
                        }
                        
                        // Incident reporting instructions
                        instructionSection(section: .incidents) {
                            InstructionItem(title: "Reporting a New Incident 📍", steps: [
                                "First, center yourself on the map using the location button (📍)",
                                "Long press on the map where the incident occurred",
                                "Note: You can only drop pins within 200 feet of your current location",
                                "If outside the range, you'll see an error message"
                            ])
                            
                            InstructionItem(title: "Selecting Incident Type", steps: [
                                "After long pressing, choose the incident type:",
                                "Verbal (🗣️): For verbal harassment or threats",
                                "Physical (👊): For physical altercations",
                                "Emergency (🚨): For life-threatening situations",
                                "Each type is color-coded on the map for easy identification"
                            ])
                        }
                        
                        // Video instructions
                        instructionSection(section: .videos) {
                            InstructionItem(title: "Adding Videos 📹", steps: [
                                "After selecting incident type, you'll be prompted to add a video",
                                "You can record a new video or select from your library",
                                "Videos must be less than 3 minutes long",
                                "Large videos will be automatically compressed"
                            ])
                            
                            InstructionItem(title: "Viewing Videos 🎬", steps: [
                                "Tap on any pin on the map to view its associated video",
                                "The video player will open fullscreen",
                                "Videos start playing automatically"
                            ])
                            
                            InstructionItem(title: "Reporting Inappropriate Videos 🚩", steps: [
                                "While watching a video, tap the flag icon (🚩) in the top left",
                                "Enter your email address in the form",
                                "Select a reason for reporting (Inappropriate, Misleading, Harmful)",
                                "Tap Submit to send the report"
                            ])
                        }
                        
                        // Account management instructions
                        instructionSection(section: .account) {
                            InstructionItem(title: "View Profile 👤", steps: [
                                "Tap the person icon at the bottom right of the screen",
                                "Your profile page will open showing your email and account options"
                            ])
                            
                            InstructionItem(title: "Settings ⚙️", steps: [
                                "Tap the gear icon at the bottom of the screen",
                                "Access app settings including:",
                                "- View tutorial again",
                                "- Toggle dark mode",
                                "- View terms of service and privacy policy"
                            ])
                            
                            InstructionItem(title: "Sign Out 🚪", steps: [
                                "Tap profile icon at the bottom right",
                                "Tap 'Sign Out' button",
                                "Confirm you want to sign out"
                            ])
                            
                            InstructionItem(title: "Delete Account ❌", steps: [
                                "Tap profile icon at the bottom right",
                                "Tap 'Settings'",
                                "Scroll down and tap 'Delete Account'",
                                "Re-enter your password to confirm",
                                "Tap 'Delete' to permanently remove your account",
                                "Warning: This action cannot be undone"
                            ])
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
            .foregroundColor(.white)
            .background(Color.black.opacity(0.9))
            .cornerRadius(20)
            .padding()
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    // Helper to create expandable instruction sections
    private func instructionSection<Content: View>(section: InstructionSection, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(spacing: 12) {
            // Section header button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    expandedSection = expandedSection == section ? nil : section
                }
            } label: {
                HStack {
                    Image(systemName: section.icon)
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Text(section.rawValue)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: expandedSection == section ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
            }
            
            // Show content when expanded
            if expandedSection == section {
                VStack(alignment: .leading, spacing: 15) {
                    content()
                }
                .padding(.leading, 20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// Component for individual instruction items
struct InstructionItem: View {
    let title: String
    let steps: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.bottom, 2)
            
            ForEach(steps.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1).")
                        .foregroundColor(.gray)
                        .frame(width: 20, alignment: .leading)
                    
                    Text(steps[index])
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.bottom, 10)
    }
}

// Preview provider
struct DetailedInstructionsView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.3)
                .ignoresSafeArea()
            
            DetailedInstructionsView()
        }
    }
} 