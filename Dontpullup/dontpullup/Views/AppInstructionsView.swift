import SwiftUI

struct AppInstructionsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                InstructionSection(title: "1. Starting the Application") {
                    Text("• Tap the \"Don't Pull Up\" app icon on your device.")
                    Text("• Wait for the initial loading screen (if present).")
                    Text("• The main map interface will appear.")
                }

                InstructionSection(title: "2. Viewing the Map and Pins") {
                    Text("• The screen displays a map of the surrounding area.")
                    Text("• Observe the colored circular markers (\"pins\") overlaid on the map. Each pin represents a user-submitted report at that location.")
                    Text("• The color of the pin corresponds to the type of incident reported.")
                }

                InstructionSection(title: "3. Viewing Pin Details (Video)") {
                    Text("• Tap directly on any colored pin marker on the map.")
                    Text("• A video player will appear, displaying the video content associated with that pin.")
                    Text("• Watch the video.")
                    Text("• Tap outside the video player area to dismiss it and return to the map view.")
                }

                InstructionSection(title: "4. Creating a New Pin (Reporting an Incident)") {
                    Text("**Authentication:**").padding(.bottom, 2)
                    Text("• To create a pin, user authentication is required.")
                    Text("• If not already logged in, use the \"Sign In\" or \"Create Account\" options (requires email/password). Alternatively, use \"Continue as Guest\" if anonymous posting is enabled and desired. Authentication must be completed before proceeding.")
                        .padding(.bottom, 5)

                    Text("**Location Requirement:**").padding(.bottom, 2)
                    Text("• Physically move to the exact location of the incident you wish to report.")
                    Text("• Pin creation is restricted to within approximately 200 feet of your current GPS location.")
                        .padding(.bottom, 5)

                    Text("**Initiate Pin Drop:**").padding(.bottom, 2)
                    Text("• Press and hold your finger firmly on the map at your current location for 1-2 seconds.")
                        .padding(.bottom, 5)

                    Text("**Record Video:**").padding(.bottom, 2)
                    Text("• The app will prompt you to record a video. Accept the prompt.")
                    Text("• The device camera will activate. Aim the camera at the subject of your report.")
                    Text("• Record the video. Ensure the video duration does not exceed the maximum limit (e.g., 3 minutes).")
                    Text("• Stop recording when finished.")
                        .padding(.bottom, 5)

                    Text("**Select Incident Type:**").padding(.bottom, 2)
                    Text("• A selection of incident type icons/categories will be presented.")
                    Text("• Tap the icon that most accurately represents the nature of the incident being reported.")
                        .padding(.bottom, 5)

                    Text("**Upload:**").padding(.bottom, 2)
                    Text("• Confirm the submission by tapping the \"Upload,\" \"Share,\" or equivalent confirmation button.")
                    Text("• The video will be compressed and uploaded. The new pin will appear on the map upon successful upload.")
                }

                InstructionSection(title: "5. Navigating the Map") {
                    Text("• **Panning:** Use one finger to touch the map and drag it in any direction (up, down, left, right) to view different areas.")
                    Text("• **Zooming In:** Tap the button displaying a plus icon (+) or magnifying glass getting larger. Each tap increases the map's zoom level, showing more detail.")
                    Text("• **Zooming Out:** Tap the button displaying a minus icon (-) or magnifying glass getting smaller. Each tap decreases the map's zoom level, showing a wider area.")
                    Text("• **Centering on User Location:** Tap the button typically represented by a target symbol or location arrow. The map will re-center on your current GPS location.")
                 }

                InstructionSection(title: "6. Filtering Pins by Type") {
                     Text("• Locate the filter buttons, usually displayed along the edge of the screen, often represented by icons matching the pin colors/types.")
                     Text("• Tap a specific filter button icon. The map will update to show only pins corresponding to that selected incident type.")
                     Text("• Tap the same filter button again to deactivate the filter and display all pin types.")
                     Text("• An additional filter button may exist (e.g., showing a phone icon 📱) to display only pins created by the current user. Tap this to toggle the \"My Pins\" filter on or off.")
                 }

                InstructionSection(title: "7. Accessing Additional Screens") {
                    Text("• **Settings:** Tap the button represented by a gear icon (⚙️). This opens the Settings screen for adjusting app preferences (Note: some settings like Dark Mode may be fixed).")
                    Text("• **Profile:** Tap the button represented by a person icon (👤). This opens the Profile screen displaying user account information (if logged in) and provides a sign-out option.")
                    Text("• **Help:** Tap the button represented by a question mark icon (❓). This opens a Help or Information screen explaining app features.")
                }
            }
            .padding() // Add padding around the entire VStack
        }
        .navigationTitle("How to Use the App")
        .navigationBarTitleDisplayMode(.inline) // Or .large depending on preference
    }
}

// Helper view for consistent section styling
struct InstructionSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.bold())
                .padding(.bottom, 4)
            content
                .font(.body)
                .foregroundColor(.secondary) // Slightly lighter text for steps
        }
    }
}

#Preview {
    NavigationView { // Wrap in NavigationView for previewing title
        AppInstructionsView()
    }
    .preferredColorScheme(.dark) // Match app theme
} 