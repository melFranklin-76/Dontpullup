import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject var authState: AuthState
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingLogoutConfirmation = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) { // Use default spacing
                    // Profile Header
                    VStack(spacing: 12) { // Use compact spacing
                        Image(systemName: "person.circle.fill") // Placeholder image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100) // Use compact size
                            .foregroundColor(.gray)
                            .padding(.top, 20)

                        Text(authState.user?.email ?? "Guest User")
                            .font(.title) // Use compact font
                            .fontWeight(.medium)

                        Text("Joined: [Date Placeholder]") // Placeholder for join date
                            .font(.subheadline) // Use compact font
                            .foregroundColor(.gray)
                    }
                    .padding(20) // Use compact padding
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                    .padding(.horizontal)
                    .padding(.top, 40) // Use compact padding

                    // User Stats
                    VStack(spacing: 20) { // Use compact spacing
                        HStack(spacing: 30) { // Use compact spacing
                            StatView(title: "Reports", value: "12") // Removed horizontalSizeClass passing
                            StatView(title: "Upvotes", value: "48") // Removed horizontalSizeClass passing
                            StatView(title: "Days", value: "30") // Removed horizontalSizeClass passing
                        }
                    }
                    .padding(.top, 40) // Use compact padding

                    // Action Buttons
                    VStack(spacing: 16) { // Use compact spacing
                        Button {
                            // Action for Edit Profile
                            print("Edit Profile Tapped")
                        } label: {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Edit Profile")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                        }
                        .buttonStyle(ProfileButtonStyle()) // Use compact font/frame via style

                        Button {
                            // Action for Settings
                            print("Settings Tapped")
                        } label: {
                            HStack {
                                Image(systemName: "gear")
                                Text("Settings")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                        }
                        .buttonStyle(ProfileButtonStyle())

                        Button(role: .destructive) {
                            showingLogoutConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "arrow.left.square.fill")
                                Text("Logout")
                                Spacer()
                            }
                        }
                        .buttonStyle(ProfileButtonStyle(isDestructive: true))

                    }
                    .padding(.horizontal) // Use default horizontal padding
                    .padding(.bottom, 20) // Use compact bottom padding

                    Spacer() // Push content to top
                }
                .padding(16) // Use default padding
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground)) // Use system background
            .alert("Confirm Logout", isPresented: $showingLogoutConfirmation) {
                 Button("Cancel", role: .cancel) { }
                 Button("Logout", role: .destructive) {
                     authViewModel.signOut()
                 }
             } message: {
                 Text("Are you sure you want to logout?")
             }
        }
    }
}

// Custom Button Style for Profile
struct ProfileButtonStyle: ButtonStyle {
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(isDestructive ? Color.red.opacity(0.1) : Color(.systemGray5))
            .foregroundColor(isDestructive ? .red : .primary)
            .font(.headline) // Use compact font size
            .frame(maxWidth: .infinity) // Use compact frame width
            .cornerRadius(10) // Use compact corner radius
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Stat View Component
struct StatView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 8) { // Use compact spacing
            Text(value)
                .font(.title) // Use compact font size
                .fontWeight(.bold)

            Text(title)
                .font(.caption) // Use compact font size
                .foregroundColor(.gray)
        }
        .frame(width: 80) // Set a fixed width for alignment
    }
}

// Preview
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AuthState.mockLoggedIn())
            .environmentObject(AuthViewModel())
    }
}

// Extension for Mock AuthState
extension AuthState {
    static func mockLoggedIn() -> AuthState {
        let state = AuthState()
        // Simulate a logged-in user for preview
        // You might need to create a mock Firebase User object or use placeholder data
        // For simplicity, we'll just set a placeholder email.
        // In a real app, you'd use a more robust mocking setup.
        // state.user = MockUser(uid: "previewUser123", email: "preview@example.com")
        state.isUserAuthenticated = .signedIn // Simulate signed in state
        // You might need a way to set a mock user object here if ProfileView uses it
        // state.user = MockFirebaseUser(uid: "mockUID", email: "mock@example.com")
        return state
    }
}

// Define a Mock Firebase User if needed for previews
// import FirebaseAuth
// struct MockFirebaseUser: User {
//     var uid: String
//     var email: String?
//     // Add other properties needed by ProfileView from the User protocol
//     var displayName: String? = nil
//     var photoURL: URL? = nil
//     var providerID: String = "mock"
//     var isAnonymous: Bool = false
//     // ... add other required properties or conformances
// } 