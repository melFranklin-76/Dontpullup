import SwiftUI

struct HelpView: View {
    @Environment(\.presentationMode) var presentationMode

    // Structure to hold help topics
    struct HelpTopic: Identifiable {
        let id = UUID()
        let title: String
        let systemImage: String
        let description: String
    }

    // Array of help topics
    let helpTopics = [
        HelpTopic(title: "Dropping a Pin", systemImage: "mappin.and.ellipse", description: "To drop a pin, press and hold on the map at the desired location (within 200ft of your current location). You must be logged in."),
        HelpTopic(title: "Viewing Videos", systemImage: "play.rectangle.fill", description: "Tap on any pin on the map to view the video associated with that location."),
        HelpTopic(title: "Filtering Incidents", systemImage: "line.horizontal.3.decrease.circle.fill", description: "Use the filter buttons on the right side of the map to show only specific types of incidents."),
        HelpTopic(title: "Deleting Your Pin", systemImage: "trash.fill", description: "Enter Edit Mode (pencil icon at the bottom). Your pins will turn red. Tap a red pin to delete it. You can only delete your own pins."),
        HelpTopic(title: "Reporting Content", systemImage: "flag.fill", description: "While viewing a video, tap the 'Report' button (flag icon) to report inappropriate or misleading content."),
        HelpTopic(title: "Location Permission", systemImage: "location.fill", description: "The app needs location access to show nearby pins and allow dropping pins. You can manage permissions in Settings."),
        HelpTopic(title: "Account Management", systemImage: "person.crop.circle.fill", description: "Tap the profile icon at the bottom to view your profile, sign out, or delete your account.")
    ]

    var body: some View {
        NavigationView {
            List {
                ForEach(helpTopics) { topic in
                    Section(header: Label(topic.title, systemImage: topic.systemImage)) {
                        Text(topic.description)
                            .font(.body)
                            .padding(.vertical, 5)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Help & FAQ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark) // Maintain dark mode consistency
    }
}

struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        HelpView()
    }
} 