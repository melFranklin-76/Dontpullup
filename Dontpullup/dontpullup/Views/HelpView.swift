import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationView {
            ZStack {
                // Background Image (Keep or remove based on design preference)
                // Image("welcome_background") // REMOVED
                //     .resizable()
                //     .aspectRatio(contentMode: .fill)
                //     .edgesIgnoringSafeArea(.all)

                // Optional Overlay (Add if needed for text contrast)
                // Color.black.opacity(0.6).edgesIgnoringSafeArea(.all)

                // Use List for better structure and scrolling
                List {
                    // Section for Community Guidelines
                    Section(header: Text("Community Guidelines").foregroundColor(.white)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Our mission is to foster transparency by documenting real experiences.")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.bottom, 4)

                            // Rules section
                            Group {
                                HStack {
                                    Text("1.")
                                        .foregroundColor(.yellow)
                                        .fontWeight(.bold)
                                    Text("Film in public spaces only")
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)
                                }
                                .font(.footnote)

                                HStack {
                                    Text("2.")
                                        .foregroundColor(.yellow)
                                        .fontWeight(.bold)
                                    Text("Share authentic, unedited experiences")
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)
                                }
                                .font(.footnote)

                                HStack {
                                    Text("3.")
                                        .foregroundColor(.yellow)
                                        .fontWeight(.bold)
                                    Text("Respect legal boundaries and privacy")
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)
                                }
                                .font(.footnote)

                                HStack {
                                    Text("4.")
                                        .foregroundColor(.yellow)
                                        .fontWeight(.bold)
                                    Text("No hate speech, nudity or harassment")
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)
                                }
                                .font(.footnote)

                                HStack {
                                    Text("5.")
                                        .foregroundColor(.yellow)
                                        .fontWeight(.bold)
                                    Text("Promote safety and respect for all")
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)
                                }
                                .font(.footnote)

                                HStack {
                                    Text("6.")
                                        .foregroundColor(.yellow)
                                        .fontWeight(.bold)
                                    Text("Violations may result in content removal")
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)
                                }
                                .font(.footnote)
                            }
                        }
                    }

                    // Section for Reporting
                    Section(header: Text("Reporting & Moderation").foregroundColor(.white)) {
                        VStack(alignment: .leading, spacing: 8) {
                             Group {
                                HStack(alignment: .top, spacing: 10) {
                                    Text("•")
                                        .foregroundColor(.yellow)
                                    Text("Use the 'Report' button to flag violations")
                                        .foregroundColor(.white)
                                }
                                .font(.caption)

                                HStack(alignment: .top, spacing: 10) {
                                    Text("•")
                                        .foregroundColor(.yellow)
                                    Text("Our team reviews reports within 24 hours")
                                        .foregroundColor(.white)
                                }
                                .font(.caption)

                                HStack(alignment: .top, spacing: 10) {
                                    Text("•")
                                        .foregroundColor(.yellow)
                                    Text("Violating content will be removed")
                                        .foregroundColor(.white)
                                }
                                .font(.caption)
                            }
                        }
                    }

                    // Section for Contact
                    Section(header: Text("Contact Us").foregroundColor(.white)) {
                        Text("Email: support@dontpullupongrandma.com")
                            .font(.caption)
                            .foregroundColor(.white)
                    }

                }
                // Apply List styles consistent with SettingsView
                .listStyle(InsetGroupedListStyle())
                .scrollContentBackground(.hidden) // Make List background clear
            }
            // Apply solid black background instead of image
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationBarTitle("Help & Guidelines", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    HelpView()
} 