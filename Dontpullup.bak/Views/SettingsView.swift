import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AuthViewModel()
    @State private var showingDeleteConfirmation = false
    @State private var password = ""
    @State private var isAnonymous: Bool
    
    init() {
        _isAnonymous = State(initialValue: Auth.auth().currentUser?.isAnonymous ?? true)
    }
    
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
                
                List {
                    // Account Section
                    Section("Account") {
                        if isAnonymous {
                            Text("You're using an anonymous account")
                                .foregroundColor(.gray)
                        } else if let email = Auth.auth().currentUser?.email {
                            Text(email)
                                .foregroundColor(.white)
                        }
                        
                        Button(action: {
                            showingDeleteConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.minus")
                                    .foregroundColor(.red)
                                Text("Delete Account")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .listRowBackground(Color.black.opacity(0.5))
                    
                    // App Section
                    Section("App") {
                        NavigationLink(destination: HelpView()) {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                Text("Help")
                            }
                            .foregroundColor(.white)
                        }
                        
                        NavigationLink(destination: ResourcesView()) {
                            HStack {
                                Image(systemName: "link.circle")
                                Text("Resources")
                            }
                            .foregroundColor(.white)
                        }
                    }
                    .listRowBackground(Color.black.opacity(0.5))
                    
                    // Version info
                    Section {
                        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                            Text("Version \(version) (\(build))")
                                .foregroundColor(.gray)
                        }
                    }
                    .listRowBackground(Color.black.opacity(0.5))
                }
                .scrollContent "link.circle")
                                Text("Resources")
                            }
                            .foregroundColor(.white)
                        }
                    }
                    .listRowBackground(Color.black.opacity(0.5))
                    
                    // Version info
                    Section {
                        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                            Text("Version \(version) (\(build))")
                                .foregroundColor(.gray)
                        }
                    }
                    .listRowBackground(Color.black.opacity(0.5))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
                if !isAnonymous {
                    SecureField("Password", text: $password)
                }
                
                Button("Cancel", role: .cancel) {
                    password = ""
                }
                
                Button("Delete", role: .destructive) {
                    Task {
                        do {
                            try await viewModel.deleteAccount(password: password.isEmpty ? nil : password)
                        } catch {
                            viewModel.alertMessage = error.localizedDescription
                            viewModel.showAlert = true
                        }
                    }
                }
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
            .alert("Error", isPresented: $viewModel.showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.alertMessage)
            }
            .preferredColorScheme(.dark)
        }
    }
}

#Preview {
    SettingsView()
} 