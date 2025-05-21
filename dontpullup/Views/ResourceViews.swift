import SwiftUI

// MARK: - Terms of Service View

struct TermsOfServiceView: View {
    var body: some View {
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
                VStack(alignment: .leading, spacing: 20) {
                    Text("Terms of Service")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.top, 20)
                    
                    Group {
                        Text("Last Updated: \(formattedDate())")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Text("1. Acceptance of Terms")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("By accessing and using the Don't Pull Up application, you accept and agree to be bound by the terms and provision of this agreement.")
                            .foregroundColor(.white)
                        
                        Text("2. User Content")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("You are solely responsible for the videos and incident reports you submit through the app. You must not upload content that is illegal, harmful, threatening, abusive, harassing, tortious, defamatory, vulgar, obscene, libelous, invasive of another's privacy, or otherwise objectionable.")
                            .foregroundColor(.white)
                        
                        Text("3. Limited License")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("We grant you a limited, non-exclusive, non-transferable license to use the Don't Pull Up application for your personal, non-commercial purposes. You may not use the app for any other purpose without our prior express written consent.")
                            .foregroundColor(.white)
                        
                        Text("4. Reporting Incidents")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("When reporting incidents, you must be within 200 feet of the location you are reporting. The app uses GPS to verify your location. False reporting or misrepresentation of incidents may result in account termination.")
                            .foregroundColor(.white)
                    }
                    
                    Group {
                        Text("5. Privacy")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Your privacy is important to us. Please review our Privacy Policy to understand how we collect, use, and disclose information.")
                            .foregroundColor(.white)
                        
                        Text("6. Disclaimer of Warranties")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("The app is provided on an \"as is\" and \"as available\" basis without any warranties of any kind. We do not guarantee that the app will be uninterrupted, secure, or error-free.")
                            .foregroundColor(.white)
                        
                        Text("7. Limitation of Liability")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("To the maximum extent permitted by law, we shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use or inability to use the app.")
                            .foregroundColor(.white)
                        
                        Text("8. Changes to Terms")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("We may update these Terms from time to time. We will notify you of any changes by posting the new Terms on this page. Your continued use of the app after such modifications will constitute your acknowledgment of the modified Terms.")
                            .foregroundColor(.white)
                        
                        Text("9. Contact Us")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("If you have any questions about these Terms, please contact us at support@dontpullup.com")
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
    
    private func formattedDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        return dateFormatter.string(from: Date(timeIntervalSince1970: 1683100800)) // May 3, 2023
    }
}

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    var body: some View {
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
                VStack(alignment: .leading, spacing: 20) {
                    Text("Privacy Policy")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.top, 20)
                    
                    Group {
                        Text("Last Updated: \(formattedDate())")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Text("This Privacy Policy describes how your personal information is collected, used, and shared when you use the Don't Pull Up application.")
                            .foregroundColor(.white)
                        
                        Text("1. Information We Collect")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("When you use Don't Pull Up, we collect several types of information:\n\n• Account Information: Email address and authentication data\n• Location Data: GPS coordinates when you use the app\n• Media Content: Videos you upload when reporting incidents\n• Usage Data: How you interact with the app")
                            .foregroundColor(.white)
                        
                        Text("2. How We Use Your Information")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("We use the information we collect to:\n\n• Provide and maintain the app functionality\n• Verify the location of reported incidents\n• Display incident reports on the map\n• Improve and optimize the app\n• Communicate with you about your account")
                            .foregroundColor(.white)
                        
                        Text("3. Sharing Your Information")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("When you report an incident, the location and type of incident will be visible to other app users. Your email address and personal information will not be shared. Videos you upload may be viewed by other app users in relation to the incident reported.")
                            .foregroundColor(.white)
                    }
                    
                    Group {
                        Text("4. Data Storage")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("We use Firebase services provided by Google to store user data, incident reports, and media content. Please review Google's Privacy Policy for information on how they handle data.")
                            .foregroundColor(.white)
                        
                        Text("5. Your Rights")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("You have the right to:\n\n• Access the personal information we have about you\n• Request deletion of your data\n• Opt out of communications\n• Lodge a complaint with a supervisory authority")
                            .foregroundColor(.white)
                        
                        Text("6. Data Security")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("We implement appropriate technical and organizational measures to protect your personal information. However, no method of transmission over the Internet or electronic storage is 100% secure.")
                            .foregroundColor(.white)
                        
                        Text("7. Changes to This Policy")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page.")
                            .foregroundColor(.white)
                        
                        Text("8. Contact Us")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("If you have any questions about this Privacy Policy, please contact us at privacy@dontpullup.com")
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
    
    private func formattedDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        return dateFormatter.string(from: Date(timeIntervalSince1970: 1683100800)) // May 3, 2023
    }
}

// MARK: - Help View

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingSettings = false
    @State private var showingProfile = false
    @State private var showingTerms = false
    @State private var showingPrivacy = false

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

// MARK: - Resources View

struct ResourcesView: View {
    var body: some View {
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
                VStack(alignment: .leading, spacing: 24) {
                    // Introduction
                    Text("Anti-Racism Resources")
                        .font(.title.bold())
                        .foregroundColor(.white)
                        .padding(.bottom, 8)
                    
                    Text("Together, we can work to create positive change. Below are resources to help educate, support, and take action against racism.")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                    
                    // Organizations
                    ResourceSection(title: "Organizations to Support", resources: [
                        Resource(
                            name: "NAACP",
                            description: "Civil rights organization working to disrupt inequality and end race-based discrimination.",
                            link: "https://naacp.org"
                        ),
                        Resource(
                            name: "Black Lives Matter",
                            description: "Global organization working to end state-sanctioned violence and oppression of Black people.",
                            link: "https://blacklivesmatter.com"
                        ),
                        Resource(
                            name: "ACLU",
                            description: "Defending civil rights and liberties through advocacy and legal action.",
                            link: "https://aclu.org"
                        )
                    ])
                    
                    // Educational Resources
                    ResourceSection(title: "Educational Resources", resources: [
                        Resource(
                            name: "Anti-Racism Resources",
                            description: "Comprehensive list of anti-racism articles, books, and media.",
                            link: "https://bit.ly/ANTIRACISMRESOURCES"
                        ),
                        Resource(
                            name: "Racial Equity Tools",
                            description: "Tools, research, and resources for racial equity and social justice.",
                            link: "https://www.racialequitytools.org"
                        )
                    ])
                    
                    // Legal Resources
                    ResourceSection(title: "Legal Resources", resources: [
                        Resource(
                            name: "Legal Defense Fund",
                            description: "Legal organization fighting for racial justice through advocacy and litigation.",
                            link: "https://www.naacpldf.org"
                        ),
                        Resource(
                            name: "Know Your Rights",
                            description: "Information about your rights when dealing with law enforcement.",
                            link: "https://www.aclu.org/know-your-rights"
                        )
                    ])
                    
                    // Mental Health Resources
                    ResourceSection(title: "Mental Health Support", resources: [
                        Resource(
                            name: "Therapy for Black Girls",
                            description: "Mental health resources and therapist directory for Black women and girls.",
                            link: "https://therapyforblackgirls.com"
                        ),
                        Resource(
                            name: "Black Mental Health Alliance",
                            description: "Culturally-competent mental health resources and support.",
                            link: "https://blackmentalhealth.com"
                        )
                    ])
                    
                    // Call to Action
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Take Action")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ActionItem(text: "Educate yourself and others about systemic racism")
                            ActionItem(text: "Support Black-owned businesses")
                            ActionItem(text: "Contact your local representatives")
                            ActionItem(text: "Register to vote and participate in elections")
                            ActionItem(text: "Document and report incidents of racism")
                            ActionItem(text: "Donate to organizations fighting for racial justice")
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Resources")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Resource Components

struct ResourceSection: View {
    let title: String
    let resources: [Resource]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2.bold())
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 20) {
                ForEach(resources) { resource in
                    ResourceLink(resource: resource)
                }
            }
        }
    }
}

struct ResourceLink: View {
    let resource: Resource
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        Button {
            if let url = URL(string: resource.link) {
                openURL(url)
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(resource.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(resource.description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

struct ActionItem: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .padding(.top, 8)
            
            Text(text)
                .font(.body)
        }
        .foregroundColor(.white.opacity(0.8))
    }
}

struct Resource: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let link: String
} 