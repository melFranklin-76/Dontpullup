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
    @StateObject private var authViewModel = AuthViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background Image
                Image("welcome_background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .edgesIgnoringSafeArea(.all)
                
                // Add Overlay
                Color.black.opacity(0.7)
                    .edgesIgnoringSafeArea(.all)

                // Content
                VStack(spacing: 0) {
                    // Top section with spacing
                    Spacer()
                    
                    // Middle section with tagline - Changed text and color to red
                    Text("VISIBILITY OVER VIOLENCE FOR COMMUNITY VALIDITY")
                        .font(.custom("BlackOpsOne-Regular", size: horizontalSizeClass == .regular ? 30 : 24))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.7), radius: 2)
                        .padding(.horizontal, horizontalSizeClass == .regular ? 40 : 20)
                    
                    Spacer()
                    
                    // Bottom section with buttons - changed colors and ensured consistent sizing
                    VStack(spacing: horizontalSizeClass == .regular ? 25 : 20) {
                        // Sign In button - Changed to RED
                        Button(action: { authViewModel.isShowingSignIn = true }) {
                            Text("Sign In")
                                .font(horizontalSizeClass == .regular ? .title3.weight(.bold) : .headline.weight(.bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .frame(height: horizontalSizeClass == .regular ? 60 : 50)
                                .background(Color.red)
                                .cornerRadius(horizontalSizeClass == .regular ? 30 : 25)
                                .shadow(color: .black.opacity(0.3), radius: 4)
                        }
                        
                        // Create Account button - Changed to GREEN
                        Button(action: { authViewModel.isShowingSignUp = true }) {
                            Text("Create Account")
                                .font(horizontalSizeClass == .regular ? .title3.weight(.bold) : .headline.weight(.bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .frame(height: horizontalSizeClass == .regular ? 60 : 50)
                                .background(Color.green)
                                .cornerRadius(horizontalSizeClass == .regular ? 30 : 25)
                                .shadow(color: .black.opacity(0.3), radius: 4)
                        }
                        
                        // Continue as Guest button - Changed to YELLOW
                        Button(action: signInAnonymously) {
                            ZStack {
                                // Background
                                RoundedRectangle(cornerRadius: horizontalSizeClass == .regular ? 30 : 25)
                                    .fill(Color.yellow)
                                    .opacity(isLoading ? 0.5 : 1.0)
                                    .frame(height: horizontalSizeClass == .regular ? 60 : 50)
                                    .shadow(color: .black.opacity(0.3), radius: 4)

                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(horizontalSizeClass == .regular ? 1.5 : 1.0)
                                } else {
                                    Text("Continue as Guest")
                                        .font(horizontalSizeClass == .regular ? .title3.weight(.bold) : .headline.weight(.bold))
                                        .foregroundColor(.black) // Changed to black for better contrast on yellow
                                }
                            }
                            .frame(minWidth: 0, maxWidth: .infinity)
                        }
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, horizontalSizeClass == .regular ? 80 : 24)
                    .padding(.bottom, max(20, geometry.safeAreaInsets.bottom + (horizontalSizeClass == .regular ? 30 : 20)))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $authViewModel.isShowingSignIn) {
            SignInView(isPresented: $authViewModel.isShowingSignIn)
        }
        .sheet(isPresented: $authViewModel.isShowingSignUp) {
            SignUpView(isPresented: $authViewModel.isShowingSignUp)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func signInAnonymously() {
        isLoading = true
        Auth.auth().signInAnonymously { result, error in
            isLoading = false
            if let error = error {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// Rename LoginView to SignInView and update its structure
struct SignInView: View {
    @Binding var isPresented: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack { // Outer ZStack for background
                    // Background Image
                    Image("welcome_background")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .edgesIgnoringSafeArea(.all)
                    
                    // Add Overlay
                    Color.black.opacity(0.7)
                        .edgesIgnoringSafeArea(.all)

                    // Original ZStack content
                    ZStack {
                        // Color.black.ignoresSafeArea() // Original black background removed
                        
                        ScrollView {
                            VStack {
                                Spacer()
                                    .frame(height: 40)
                                
                                VStack(spacing: 20) {
                                    TextField("Email", text: $email)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .textContentType(.emailAddress)
                                        .autocapitalization(.none)
                                        .font(.system(size: 16))
                                    
                                    SecureField("Password", text: $password)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .textContentType(.password)
                                        .font(.system(size: 16))
                                }
                                .padding(.horizontal, 24)
                                
                                Spacer()
                                
                                // Bottom button - updated to red
                                Button(action: login) {
                                    ZStack {
                                        if isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        } else {
                                            Text("Sign In")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                                .cornerRadius(25)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 40)
                                .disabled(isLoading)
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Sign In")
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading: 
                Button("Cancel") {
                    isPresented = false
                }
                .foregroundColor(.white)
            )
        }
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
            GeometryReader { geometry in
                ZStack { // Outer ZStack for background
                    // Background Image
                    Image("welcome_background")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .edgesIgnoringSafeArea(.all)
                    
                    // Add Overlay
                    Color.black.opacity(0.7)
                        .edgesIgnoringSafeArea(.all)

                    // Original ZStack content
                    ZStack {
                        // Color.black.ignoresSafeArea() // Original black background removed
                        
                        ScrollView {
                            VStack {
                                Spacer()
                                    .frame(height: 40)
                                
                                VStack(spacing: 20) {
                                    TextField("Email", text: $email)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .textContentType(.emailAddress)
                                        .autocapitalization(.none)
                                        .font(.system(size: 16))
                                    
                                    SecureField("Password", text: $password)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .textContentType(.newPassword)
                                        .font(.system(size: 16))
                                    
                                    SecureField("Confirm Password", text: $confirmPassword)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .textContentType(.newPassword)
                                        .font(.system(size: 16))
                                }
                                .padding(.horizontal, 24)
                                
                                Spacer()
                                
                                // Bottom button - kept as green
                                Button(action: signUp) {
                                    ZStack {
                                        if isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        } else {
                                            Text("Create Account")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                .cornerRadius(25)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 40)
                                .disabled(isLoading)
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Create Account")
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading: 
                Button("Cancel") {
                    isPresented = false
                }
                .foregroundColor(.white)
            )
        }
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