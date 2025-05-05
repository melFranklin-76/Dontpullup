import SwiftUI
import FirebaseAuth
import Network

struct AuthBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            // Background Image
            Image("welcome_background")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .edgesIgnoringSafeArea(.all)
            
            // Semi-transparent overlay
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            // Content
            content
        }
    }
}

extension View {
    func withAuthBackground() -> some View {
        modifier(AuthBackgroundModifier())
    }
}

struct AuthView: View {
    @EnvironmentObject private var authState: AuthState
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingLogin = false
    @State private var showingSignUp = false
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 40) {
            // App Title
            VStack(spacing: 0) {
                Text("DON'T PULL UP")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(.red)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                
                Text("ON GRANDMA")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .red.opacity(0.5), radius: 1, x: 0, y: 1)
                    .rotationEffect(.degrees(-20))
                    .offset(y: 5)
            }
            .padding(.top, 60)
            
            // Main Message
            Text("Show us who they are\nso we can show them who we not")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.vertical, 20)
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            
            Spacer()
            
            // Network Status
            if !networkMonitor.isConnected {
                    .offset(y: 5)
            }
            .padding(.top, 60)
            
            // Main Message
            Text("Show us who they are\nso we can show them who we not")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.vertical, 20)
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            
            Spacer()
            
            // Network Status
            if !networkMonitor.isConnected {
                Text("No Internet Connection")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(5)
            }
            
            // Authentication Buttons
            VStack(spacing: 20) {
                // Sign In Button
                Button(action: { showingLogin = true }) {
                    Text("Sign In")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.3), radius: 3)
                }
                
                // Sign Up Button
                Button(action: { showingSignUp = true }) {
                    Text("Create Account")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.green)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.3), radius: 3)
                }
                
                // Anonymous Continue Button
                Button(action: {
                    guard networkMonitor.isConnected else {
                        errorMessage = "Internet connection required for authentication"
                        showError = true
                        return
                    }
                    
                    isLoading = true
                    Task {
                        do {
                            try await authState.signInAnonymously()
                            isLoading = false
                        } catch {
                            isLoading = false
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .                // Anonymous Continue Button
                Button(action: {
                    guard networkMonitor.isConnected else {
                        errorMessage = "Internet connection required for authentication"
                        showError = true
                        return
                    }
                    
                    isLoading = true
                    Task {
                        do {
                            try await authState.signInAnonymously()
                            isLoading = false
                        } catch {
                            isLoading = false
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(12)
                    } else {
                        Text("Continue Anonymously")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.red)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.3), radius: 3)
                    }
                }
                .disabled(isLoading)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
        }
        .withAuthBackground()
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingLogin) {
            LoginView(isPresented: $showingLogin)
        }
        .sheet(isPresented: $showingSignUp) {
            SignUpView(isPresented: $showingSignUp)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
}

// Login View
struct LoginView: View {
    @Binding var isPresented: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.emailAddress)
                    .autocapitalization(.none}

// Login View
struct LoginView: View {
    @Binding var isPresented: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.password)
                
                Button(action: login) {
                    Text("Sign In")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .disabled(isLoading)
            }
            .padding()
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .withAuthBackground()
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func login() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields"
            showError = true
            return
        }
        
        isLoading = true
        Task {
            do {
                try await authState.signIn(email: email, password: password)
                isLoading = false
                isPresented = false
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// Sign Up View
struct SignUpView: View {
    @Binding var isPresented: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var is
        }
        
        isLoading = true
        Task {
            do {
                try await authState.signIn(email: email, password: password)
                isLoading = false
                isPresented = false
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// Sign Up View
struct SignUpView: View {
    @Binding var isPresented: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.newPassword)
                
                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.newPassword)
                
                Button(action: signUp) {
                    Text("Create Account")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.green)
                        .cornerRadius(10)
                }
                .disabled(isLoading)
            }
            .padding()
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .withAuthBackground()
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func signUp() {
        guard !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            errorMessage = "Please fill in all fields"
            showError = trueItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .withAuthBackground()
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func signUp() {
        guard !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            errorMessage = "Please fill in all fields"
            showError = true
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            showError = true
            return
        }
        
        isLoading = true
        Task {
            do {
                try await authState.signUp(email: email, password: password)
                isLoading = false
                isPresented = false
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
