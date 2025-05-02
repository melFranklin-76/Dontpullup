import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject private var authState: AuthState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showSignOutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String? = nil
    @State private var showDeleteError = false
    
    var body: some View {
        NavigationView {
            ZStack { // Outer ZStack for background
                // Original ZStack content becomes the main content container
                VStack {
                    // User avatar and name
                    VStack(spacing: horizontalSizeClass == .regular ? 20 : 12) {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: horizontalSizeClass == .regular ? 150 : 100, height: horizontalSizeClass == .regular ? 150 : 100)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(.white)
                                    .padding(horizontalSizeClass == .regular ? 30 : 20)
                            )
                        
                        Text(userName)
                            .font(horizontalSizeClass == .regular ? .largeTitle : .title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(userEmail)
                            .font(horizontalSizeClass == .regular ? .title3 : .subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, horizontalSizeClass == .regular ? 60 : 40)
                    
                    // Stats section
                    VStack(spacing: horizontalSizeClass == .regular ? 30 : 20) {
                        HStack(spacing: horizontalSizeClass == .regular ? 60 : 30) {
                            StatView(title: "Reports", value: "12", horizontalSizeClass: horizontalSizeClass)
                            StatView(title: "Upvotes", value: "48", horizontalSizeClass: horizontalSizeClass)
                            StatView(title: "Days", value: "30", horizontalSizeClass: horizontalSizeClass)
                        }
                    }
                    .padding(.top, horizontalSizeClass == .regular ? 60 : 40)
                    
                    Spacer()
                    
                    // Account Actions Section - Use adaptive width for iPad
                    VStack(spacing: horizontalSizeClass == .regular ? 24 : 16) {
                        // Sign out button
                        Button(action: {
                            showSignOutConfirmation = true
                        }) {
                            Text("Sign Out")
                                .font(horizontalSizeClass == .regular ? .title3 : .headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: horizontalSizeClass == .regular ? 400 : .infinity)
                                .background(Color.red.opacity(0.8))
                                .cornerRadius(horizontalSizeClass == .regular ? 15 : 10)
                        }
                        .frame(maxWidth: .infinity) // Ensure button is always centered
                        
                        // Delete Account button - Make more prominent to satisfy Apple's requirements
                        Button(action: {
                            showDeleteAccountConfirmation = true
                        }) {
                            Text("Delete My Account")
                                .font(horizontalSizeClass == .regular ? .title3 : .headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: horizontalSizeClass == .regular ? 400 : .infinity)
                                .background(Color.red)
                                .cornerRadius(horizontalSizeClass == .regular ? 15 : 10)
                        }
                        .frame(maxWidth: .infinity) // Ensure button is always centered
                    }
                    .padding(.horizontal, horizontalSizeClass == .regular ? 40 : 16)
                    .padding(.bottom, horizontalSizeClass == .regular ? 40 : 20)
                }
                .padding(horizontalSizeClass == .regular ? 32 : 16)
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            // Sign Out Alert
            .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    _ = authState.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            // Delete Account Alert
            .alert("Delete Account", isPresented: $showDeleteAccountConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
            } message: {
                Text("This will permanently delete your account and all associated data. This action cannot be undone.")
            }
            // Error Alert
            .alert("Error Deleting Account", isPresented: $showDeleteError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteError ?? "An unknown error occurred.")
            }
            // Deletion Progress Overlay
            .overlay(
                Group {
                    if isDeleting {
                        ZStack {
                            Color.black.opacity(0.7)
                                .ignoresSafeArea()
                            VStack(spacing: 16) {
                                ProgressView("Deleting your account...")
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .foregroundColor(.white)
                                    .scaleEffect(horizontalSizeClass == .regular ? 1.5 : 1.0)
                                Text("This may take a moment.")
                                    .font(horizontalSizeClass == .regular ? .body : .footnote)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                        }
                    }
                }
            )
        }
        .navigationViewStyle(.stack)
    }
    
    private func deleteAccount() async {
        isDeleting = true
        
        let result = await authState.deleteAccount()
        
        DispatchQueue.main.async {
            self.isDeleting = false
            
            switch result {
            case .success:
                // Account deleted, will be handled by AuthState listener
                // Optionally post a notification for any special handling
                NotificationCenter.default.post(name: NSNotification.Name("UserLoggedOut"), object: nil)
                
            case .failure(let error):
                self.deleteError = error.localizedDescription
                self.showDeleteError = true
            }
        }
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
    var horizontalSizeClass: UserInterfaceSizeClass?
    
    var body: some View {
        VStack(spacing: horizontalSizeClass == .regular ? 12 : 8) {
            Text(value)
                .font(horizontalSizeClass == .regular ? .largeTitle : .title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(horizontalSizeClass == .regular ? .headline : .caption)
                .foregroundColor(.gray)
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthState.shared)
} 