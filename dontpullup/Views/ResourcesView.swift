import SwiftUI

/**
 The ResourcesView struct is responsible for displaying a list of anti-racism resources.
 It provides sections for organizations, educational resources, legal resources, and mental health support.
 */
struct ResourcesView: View {
    /**
     The body property defines the content and behavior of the resources view.
     It includes a background image, a semi-transparent overlay, and a scrollable list of resources.
     */
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

/**
 The ResourceSection struct is responsible for displaying a section of resources.
 It includes a title and a list of ResourceLink views.
 */
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

/**
 The ResourceLink struct is responsible for displaying a link to a resource.
 It includes the resource name, description, and a button to open the link.
 */
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

/**
 The ActionItem struct is responsible for displaying an action item in the call to action section.
 It includes a bullet point and the action text.
 */
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

/**
 The Resource struct represents a resource with a name, description, and link.
 It conforms to the Identifiable protocol.
 */
struct Resource: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let link: String
}
