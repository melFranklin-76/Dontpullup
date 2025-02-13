import SwiftUI
import FirebaseAuth
import Network

/**
 The AuthBackgroundModifier struct is a view modifier that adds a background image and a semi-transparent overlay to the content.
 */
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
    /**
     Adds the AuthBackgroundModifier to the view.
     
     - Returns: A view with the AuthBackgroundModifier applied.
     */
    func withAuthBackground() -> some View {
        modifier(AuthBackgroundModifier())
    }
}

/**
 The AuthView struct is responsible for displaying the authentication screen.
 It provides options for signing in, creating an account, and continuing anonymously.
 */
struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel()
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingLogin = false
    @State private var showingSignUp = false
    
    /**
     The body property defines the content and behavior of the authentication screen.
     It includes the app title, main message, network status, and authentication buttons.
     */
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
                    
                    Task {
                        do {
                            try await viewModel.signInAnonymously()
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }) {
                    if viewModel.isLoading {
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
                .disabled(viewModel.isLoading)
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

/**
 The LoginView struct is responsible for displaying the login screen.
 It provides fields for entering email and password, and a button to sign in.
 */
struct LoginView: View {
    @Binding var isPresented: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    /**
     The body property defines the content and behavior of the login screen.
     It includes fields for email and password, and a sign-in button.
     */
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
    
    /**
     Handles the login process by signing in with the provided email and password.
     If the login is successful, dismisses the login view.
     If an error occurs, displays an error message.
     */
    private func login() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields"
            showError = true
            return
        }
        
        isLoading = true
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            isLoading = false
            if let error = error {
                errorMessage = error.localizedDescription
                showError = true
            } else {
                isPresented = false
            }
        }
    }
}

/**
 The SignUpView struct is responsible for displaying the sign-up screen.
 It provides fields for entering email, password, and confirming the password, and a button to create an account.
 */
struct SignUpView: View {
    @Binding var isPresented: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    /**
     The body property defines the content and behavior of the sign-up screen.
     It includes fields for email, password, and confirming the password, and a create account button.
     */
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
    
    /**
     Handles the sign-up process by creating a new user with the provided email and password.
     If the sign-up is successful, dismisses the sign-up view.
     If an error occurs, displays an error message.
     */
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
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            isLoading = false
            if let error = error {
                errorMessage = error.localizedDescription
                showError = true
            } else {
                isPresented = false
            }
        }
    }
}
