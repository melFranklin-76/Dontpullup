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

                // Replace VStack content with ScrollView containing help text
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        // --- Community Guidelines --- 
                        Text("Community Guidelines")
                            .font(.title2).bold()
                            .foregroundColor(.white)
                            .padding(.bottom, 5)
                        
                        Text("Our mission is to foster transparency and unity by documenting real experiences—whether exposing injustice or showcasing support. To keep our community safe and impactful, follow these rules:")
                            .foregroundColor(.white)
                        
                        Group {
                            Text("1. Film in Public Spaces Only")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("- Record in public areas (e.g., stores, streets) with no privacy expectation.")
                                .foregroundColor(.white)
                            Text("- Do not upload videos from private settings or that expose personal details (e.g., addresses).")
                                .foregroundColor(.white)
                        }

                        Group {
                            Text("2. Share Authentic Experiences")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("- Document discrimination (e.g., unfair treatment based on race or religion) or positive acts (e.g., cross-community support).")
                                .foregroundColor(.white)
                            Text("- Videos must be unedited, up to 5 minutes, and authentic—not staged or misleading.") // Adjusted duration
                                .foregroundColor(.white)
                        }
                        
                        Group {
                            Text("3. Respect Legal Boundaries")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("- Comply with local laws on filming and audio recording (e.g., consent where required).")
                                .foregroundColor(.white)
                            Text("- Do not upload copyrighted material unless you have permission.")
                                .foregroundColor(.white)
                        }
                        
                        Group {
                            Text("4. Prohibited Content")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("- Hate speech, threats, or harassment, except when documenting discrimination to expose it.")
                                .foregroundColor(.white)
                            Text("- Nudity, graphic violence, or illegal activities.")
                                .foregroundColor(.white)
                            Text("- False or defamatory content aimed at harming others.")
                                .foregroundColor(.white)
                        }
                        
                        Group {
                            Text("5. Promote Safety and Respect")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("- Use the app to inform and uplift, not to bully or harass.")
                                .foregroundColor(.white)
                            Text("- Respect all users' right to share their stories.")
                                .foregroundColor(.white)
                        }
                        
                        Group {
                            Text("6. Enforcement")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("- Violations may result in content removal, account suspension, or banning.")
                                .foregroundColor(.white)
                        }
                        
                        Text("By uploading, you confirm your content meets these guidelines and local laws.")
                            .foregroundColor(.white)
                            .padding(.top, 5)
                        
                        Divider().background(Color.gray).padding(.vertical, 10)
                        
                        // --- Reporting and Moderation Process --- 
                        Text("Reporting and Moderation Process")
                            .font(.title2).bold()
                            .foregroundColor(.white)
                            .padding(.bottom, 5)

                        Text("We maintain a safe platform through active moderation:")
                            .foregroundColor(.white)

                        Group {
                            Text("1. Reporting")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("- Use the ‘Report’ button to flag violations.")
                                .foregroundColor(.white)
                        }
                        Group {
                            Text("2. Review")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("- Our team reviews reports within 24 hours, using tools like AWS Rekognition where needed.")
                                .foregroundColor(.white)
                        }
                        Group {
                            Text("3. Action")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("- Violating content is removed; repeat offenders may be blocked.")
                                .foregroundColor(.white)
                        }
                        Group {
                            Text("4. Appeals")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("- Email support@dontpullupongrandma.com")
                                .foregroundColor(.white)
                                .tint(.blue)
                        }
                        
                        Divider().background(Color.gray).padding(.vertical, 10)
                        
                        // --- Contact Us --- 
                        Text("Contact Us")
                            .font(.title2).bold()
                            .foregroundColor(.white)
                            .padding(.bottom, 5)

                        Group {
                             Text("- Email: support@dontpullupongrandma.com")
                                .foregroundColor(.white)
                                .tint(.blue)
                             Text("- Website: dontpullupongrandma.com/support")
                                .foregroundColor(.white)
                                .tint(.blue) // Consider making this a Link if possible
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitle("Help & Guidelines") // Set appropriate title
            .navigationBarTitleDisplayMode(.inline)
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