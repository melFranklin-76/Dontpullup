import SwiftUI

/// Tutorial overlay that shows as a series of instruction screens
/// for anonymous users or first-time users
struct TutorialOverlayView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    
    // Tutorial content pages
    private let tutorialPages = [
        TutorialPage(
            title: "Welcome to Don't Pull Up",
            message: "This app helps you identify and share incidents in your area. Swipe or tap to continue.",
            emoji: "🗺️"
        ),
        TutorialPage(
            title: "Map Navigation",
            message: "Pan and zoom the map to explore your area. Tap the location button to center on your position.",
            emoji: "📍"
        ),
        TutorialPage(
            title: "Incident Filters",
            message: "Use the buttons on the right to filter incidents by type: verbal, physical, or emergency.",
            emoji: "📢"
        ),
        TutorialPage(
            title: "Reporting Incidents",
            message: "Tap the pencil icon to enter edit mode, then long-press within 200 feet of your location to drop a pin.",
            emoji: "📌"
        ),
        TutorialPage(
            title: "Allow access to photo library, select a video (max 3 min).",
            message: "The upload runs in the background & map updates automatically.",
            emoji: "🎬"
        ),
        TutorialPage(
            title: "Your Pins",
            message: "Tap the phone icon to view only pins you've dropped. You can edit or delete your own pins.",
            emoji: "📱"
        ),
        TutorialPage(
            title: "Map Types",
            message: "Toggle between standard and satellite view by tapping the map icon in the toolbar.",
            emoji: "🌎"
        ),
        TutorialPage(
            title: "Offline Mode",
            message: "You can still view previously loaded pins when offline, but can't add new ones.",
            emoji: "📶"
        ),
        TutorialPage(
            title: "Sign In",
            message: "Create an account to save your data across devices and access all features.",
            emoji: "👤"
        ),
        TutorialPage(
            title: "Settings",
            message: "Access app settings, terms of service, and privacy policy through the gear icon.",
            emoji: "⚙️"
        ),
        TutorialPage(
            title: "Help",
            message: "Tap the question mark icon for detailed help on using the app.",
            emoji: "❓"
        ),
        TutorialPage(
            title: "Ready to Go!",
            message: "You're all set! Tap to start using Don't Pull Up.",
            emoji: "🚀"
        )
    ]
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.9)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    advanceTutorial()
                }
            
            // Tutorial content with more visible styling
            VStack {
                Spacer()
                
                // Emoji at top
                Text(tutorialPages[currentPage].emoji)
                    .font(.system(size: 70))
                    .shadow(color: .white.opacity(0.3), radius: 10)
                    .padding(.bottom, 30)
                
                // Main content
                VStack(spacing: 20) {
                    Text(tutorialPages[currentPage].title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text(tutorialPages[currentPage].message)
                        .font(.body)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 1)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(20)
                .background(Color.black.opacity(0.5))
                .cornerRadius(15)
                
                Spacer()
                
                // Page indicator
                Text("Tap anywhere to continue (\(currentPage + 1)/\(tutorialPages.count))")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.gray.opacity(0.6))
                    .cornerRadius(8)
                    .padding(.bottom, 40)
            }
            .padding()
        }
        .transition(.opacity.combined(with: .scale))
        .zIndex(1000)
        .shadow(color: .black, radius: 20)
        .animation(.easeInOut, value: currentPage)
    }
    
    private func advanceTutorial() {
        if currentPage < tutorialPages.count - 1 {
            currentPage += 1
        } else {
            // Tutorial completed
            withAnimation {
                isPresented = false
            }
        }
    }
}

/// Model for tutorial page content
struct TutorialPage {
    let title: String
    let message: String
    let emoji: String
}

// Preview
struct TutorialOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        TutorialOverlayView(isPresented: .constant(true))
            .preferredColorScheme(.dark)
    }
} 