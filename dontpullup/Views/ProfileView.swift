import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject private var authState: AuthState
    @Environment(\.dismiss) private var dismiss
    @State private var showSignOutConfirmation = false
    
    var body: some View {
        NavigationView {
            ZStack { // Outer ZStack for background
                // Background Image
                Image("welcome_background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
                
                // Darker overlay to clearly separate from map content
                Color.black.opacity(0.9)
                    .edgesIgnoringSafeArea(.all)
                
                // Original ZStack content
                ScrollView {
                    VStack(spacing: 24) { // Increased spacing between main sections
                        // Add spacing at the top to prevent crowding with navigation bar
                        Spacer()
                            .frame(height: 20)
                            
                        // User avatar and name
                        VStack(spacing: 16) { // Increased spacing between avatar and text
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundColor(.white)
                                        .padding(20)
                                )
                            
                            VStack(spacing: 8) { // Proper spacing between name and email
                                Text(userName)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text(userEmail)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.top, 20)
                        
                        // Stats section with improved spacing
                        VStack(spacing: 16) {
                            HStack(spacing: 36) { // Increased spacing between stats
                                StatView(title: "Reports", value: "12")
                                StatView(title: "Upvotes", value: "48")
                                StatView(title: "Days", value: "30")
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, 24)
                        
                        Spacer(minLength: 40) // More space above sign out button
                        
                        // Sign out button
                        Button(action: {
                            showSignOutConfirmation = true
                        }) {
                            Text("Sign Out")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.red)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40) // More padding at bottom
                    }
                    .padding(.horizontal)
                    .frame(minHeight: UIScreen.main.bounds.height - 120) // Ensure content fills vertical space
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    authState.signOut()
                    
                    // Force immediate UI update while Firebase callback propagates
                    authState.isAuthenticated = false
                    authState.currentUser = nil
                    
                    // Immediately close the Profile sheet
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private var userName: String {
        if let user = authState.currentUser {
            return user.displayName ?? "Anonymous User"
        }
        return "Anonymous User"
    }
    
    private var userEmail: String {
        if let user = authState.currentUser, let email = user.email {
            return email
        }
        return "No email provided"
    }
}

struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(minWidth: 70) // Ensure stat views have consistent width
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthState.shared)
} 