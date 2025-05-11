import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingSettings = false
    @State private var showingProfile = false
    @State private var showingTerms = false // State for Terms sheet
    @State private var showingPrivacy = false // State for Privacy sheet

    var body: some View {
        // Wrap in NavigationView to get a nav bar for the Done button and handle safe area
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

                VStack(spacing: 0) {
                    // Add explicit spacer at the top to prevent navigation bar crowding
                    Spacer().frame(height: 20)
                    
                    // Title with clear spacing
                    Text("Help & Resources")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                        .foregroundColor(.white)

                    // Central Action Buttons
                    VStack(spacing: 24) { // Increased spacing between buttons
                        actionButton(title: "Settings", systemImage: "gearshape.fill") {
                            showingSettings = true
                        }

                        actionButton(title: "Profile", systemImage: "person.fill") {
                            showingProfile = true
                        }

                        actionButton(title: "Terms of Service", systemImage: "doc.text.fill") {
                            showingTerms = true
                        }

                        actionButton(title: "Privacy Policy", systemImage: "shield.lefthalf.filled") {
                            showingPrivacy = true
                        }
                    }
                    .padding(.horizontal, 40) // Add horizontal padding
                    .padding(.top, 20) // Add top padding

                    Spacer() // Pushes the central content up
                    Spacer() // Add more space at the bottom
                }
                .padding(.top, 16) // Additional top padding to ensure no crowding
            }
            // Add Navigation Bar items
            .navigationBarTitleDisplayMode(.inline)
            // Optionally add a title if desired, or leave it blank
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            }
            .padding(.vertical, 8) // Add vertical padding to increase tap target
            )
        }
        .navigationViewStyle(.stack) // Use stack style for modal presentation
        .preferredColorScheme(.dark) // Ensure dark mode for the NavigationView itself
        // Sheets for presenting modal views
        .sheet(isPresented: $showingSettings) {
            // Assuming SettingsView manages its own NavigationView if needed
            SettingsView()
        }
        .sheet(isPresented: $showingProfile) {
            // Assuming ProfileView manages its own NavigationView if needed
            ProfileView()
        }
        .sheet(isPresented: $showingTerms) {
            NavigationView {
                TermsOfServiceView()
                    .navigationBarItems(trailing: Button("Done") { showingTerms = false }
                    .padding(.vertical, 8))
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showingPrivacy) {
            NavigationView {
                PrivacyPolicyView()
                    .navigationBarItems(trailing: Button("Done") { showingPrivacy = false }
                    .padding(.vertical, 8))
            }
            .preferredColorScheme(.dark)
        }
    }

    // Helper function for creating consistent action buttons
    private func actionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .frame(width: 30) // Align icons
                Text(title)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .opacity(0.5)
            }
            .padding(.vertical, 16) // Increased vertical padding for better touch targets
            .padding(.horizontal, 20) // Consistent horizontal padding
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.5))
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
}

#Preview {
    HelpView()
} 