import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject private var authState: AuthState
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
                ZStack {
                    // Color.black.edgesIgnoringSafeArea(.all) // Original black background removed
                    
                    VStack {
                        // User avatar and name
                        VStack(spacing: 8) {
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
                            
                            Text(userName)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text(userEmail)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 40)
                        
                        // Stats section
                        VStack(spacing: 16) {
                            HStack(spacing: 24) {
                                StatView(title: "Reports", value: "12")
                                StatView(title: "Upvotes", value: "48")
                                StatView(title: "Days", value: "30")
                            }
                        }
                        .padding(.top, 40)
                        
                        Spacer()
                        
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
                        .padding(.bottom, 20)
                    }
                    .padding()
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    _ = authState.signOut()
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
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthState.shared)
} 