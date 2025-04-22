import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background Image
                Image("welcome_background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
                
                // Semi-transparent overlay
                Color.black.opacity(0.7)
                    .edgesIgnoringSafeArea(.all)
                
                List {
                    // Basic Usage
                    Section("Basic Usage") {
                        HelpRow(title: "Viewing the Map",
                               description: "Pan and zoom the map using standard gestures. Toggle between map types using the map button.")
                        
                        HelpRow(title: "Finding Your Location",
                               description: "Tap the location button to center the map on your current position.")
                        
                        HelpRow(title: "Filtering Incidents",
                               description: "Use the filter buttons on the right to show/hide different types of incidents.")
                    }
                    .listRowBackground(Color.black.opacity(0.5))
                    
                    // Video Guidelines
                    Section("Video Guidelines") {
                        HelpRow(title: "Video Length Limit",
                               description: "Videos must be 5 minutes or shorter. For longer videos, please contact support@dontpullup.temp for manual review.")
                        
                        HelpRow(title: "Video Quality",
                               description: "Videos will be compressed for efficient upload. For best quality, record in well-lit conditions.")
                    }
                    .listRowBackground(Color.black.opacity(0.5))
                    
                    // Reporting Incidents
                    Section("Reporting Incidents") {
                        HelpRow(title: "Adding a New Incident",
                               description: "Long press on the map within 200 feet of your location to start reporting an incident.")
                        
                        HelpRow(title: "Recording Evidence",
                               description: "Select an incident type, then choose or record a video (max 5 minutes).")
                        
                        HelpRow(title: "Upload Status",
                               description: "A progress bar will appear while your video uploads. Keep the app open until complete.")
                    }
                    .listRowBackground(Color.black.opacity(0.5))
                    
                    // Managing Content
                    Section("Managing Content") {
                        HelpRow(title: "Viewing Incidents",
                               description: "Tap any pin on the map to view the associated video evidence.")
                        
                        HelpRow(title: "Deleting Your Content",
                               description: "Enter edit mode using the edit button, then tap your pins to delete them.")
                    }
                    .listRowBackground(Color.black.opacity(0.5))
                    
                    // Safety Guidelines
                    Section("Safety Guidelines") {
                        HelpRow(title: "Emergency Situations",
                               description: "Always call 911 first in emergencies. This app is for awareness only.")
                        
                        HelpRow(title: "Personal Safety",
                               description: "Never put yourself in danger to record an incident. Stay at a safe distance.")
                        
                        HelpRow(title: "Privacy Concerns",
                               description: "Only record in public spaces and respect privacy laws.")
                    }
                    .listRowBackground(Color.black.opacity(0.5))
                    
                    // Support & Feedback
                    Section("Support & Feedback") {
                        HelpRow(title: "Reporting Issues",
                               description: "Contact support if you encounter technical problems or need to report abuse.")
                        
                        HelpRow(title: "Content Guidelines",
                               description: "False reports or misuse will result in account termination.")
                    }
                    .listRowBackground(Color.black.opacity(0.5))
                    
                    // Legal Information
                    Section("Legal Information") {
                        NavigationLink("Terms of Service") {
                            ZStack {
                                // Background Image
                                Image("welcome_background")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .edgesIgnoringSafeArea(.all)
                                
                                // Semi-transparent overlay
                                Color.black.opacity(0.7)
                                    .edgesIgnoringSafeArea(.all)
                                
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 15) {
                                        Text("Terms of Service")
                                            .font(.title)
                                            .foregroundColor(.white)
                                            .padding(.bottom)
                                        
                                        Group {
                                            Text("1. Acceptance of Terms")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            Text("By accessing or using Don't Pull Up, you agree to be bound by these terms.")
                                                .foregroundColor(.white.opacity(0.8))
                                            
                                            Text("2. User Responsibilities")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            Text("Users must provide accurate information and use the app responsibly.")
                                                .foregroundColor(.white.opacity(0.8))
                                            
                                            Text("3. Content Guidelines")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            Text("Users may not upload false, misleading, or defamatory content.")
                                                .foregroundColor(.white.opacity(0.8))
                                            
                                            Text("4. Privacy & Data")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            Text("We collect and store user data as outlined in our Privacy Policy.")
                                                .foregroundColor(.white.opacity(0.8))
                                            
                                            Text("5. Termination")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            Text("We reserve the right to terminate accounts for violations of these terms.")
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                    }
                                    .padding()
                                }
                            }
                        }
                        
                        NavigationLink("Privacy Policy") {
                            ZStack {
                                // Background Image
                                Image("welcome_background")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .edgesIgnoringSafeArea(.all)
                                
                                // Semi-transparent overlay
                                Color.black.opacity(0.7)
                                    .edgesIgnoringSafeArea(.all)
                                
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 15) {
                                        Text("Privacy Policy")
                                            .font(.title)
                                            .foregroundColor(.white)
                                            .padding(.bottom)
                                        
                                        Group {
                                            Text("1. Information We Collect")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            Text("Location data, video content, and account information.")
                                                .foregroundColor(.white.opacity(0.8))
                                            
                                            Text("2. How We Use Your Data")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            Text("To provide location-based services and display user-generated content.")
                                                .foregroundColor(.white.opacity(0.8))
                                            
                                            Text("3. Data Storage")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            Text("Content is stored securely using Firebase services.")
                                                .foregroundColor(.white.opacity(0.8))
                                            
                                            Text("4. User Rights")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            Text("Users can delete their content and request account deletion.")
                                                .foregroundColor(.white.opacity(0.8))
                                            
                                            Text("5. Third-Party Services")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            Text("We use Firebase for authentication and storage services.")
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                    }
                                    .padding()
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.black.opacity(0.5))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Help & Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct HelpRow: View {
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            Text(description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HelpView()
}
