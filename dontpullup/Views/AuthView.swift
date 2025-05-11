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
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @EnvironmentObject var authState: AuthState
    
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    @State private var isShowingSignIn = false
    @State private var isShowingSignUp = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background Image
                Image("welcome_background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .edgesIgnoringSafeArea(.all)
                
                // Semi-transparent overlay
                Color.black.opacity(0.7)
                    .edgesIgnoringSafeArea(.all)
                
                // Content
                VStack(spacing: 0) {
                    // Top section with title and adequate spacing
                    Spacer().frame(height: geometry.safeAreaInsets.top + 40)
                    
                    // App title (DON'T PULL UP) - REMOVED
                    
                    // Middle section with tagline and improved spacing
                    Text("Show us who they are\\nso we can show them who we not")
                        .font(.custom("BlackOpsOne-Regular", size: 20))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.5), radius: 3)
                        .padding(.horizontal, 20)
                        .padding(.top, 30) // Adjusted top padding
                        .padding(.bottom, 30) // Adjusted bottom padding
                    
                    Spacer()
                    
                    // Bottom section with buttons
                    VStack(spacing: 20) { // Increased spacing between buttons
                        Button(action: { isShowingSignIn = true }) {
                            Text("Sign In")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .frame(height: 55) // Increased touch target
                                .background(Color.blue)
                                .cornerRadius(25)
                                .shadow(color: .black.opacity(0.3), radius: 4)
                        }
                        .padding(.horizontal, 24)
                        .frame(maxWidth: 400)
                        
                        Button(action: { isShowingSignUp = true }) {
                            Text("Create Account")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .frame(height: 55) // Increased touch target
                                .background(Color.green)
                                .cornerRadius(25)
                                .shadow(color: .black.opacity(0.3), radius: 4)
                        }
                        .padding(.horizontal, 24)
                        .frame(maxWidth: 400)
                        
                        Button(action: { performSignInAnonymously() }) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                            } else {
                                Text("Continue as Guest")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                        }
                        .padding(.horizontal, 24)
                        .frame(maxWidth: 400)
                        .disabled(isLoading)
                        .padding(.top, 12)
                    }
                    .padding(.bottom, max(30, geometry.safeAreaInsets.bottom + 40))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $isShowingSignIn) {
            SignInView(isPresented: $isShowingSignIn)
                .environmentObject(authState)
        }
        .sheet(isPresented: $isShowingSignUp) {
            SignUpView(isPresented: $isShowingSignUp)
                .environmentObject(authState)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func performSignInAnonymously() {
        isLoading = true
        authState.signInAnonymously { result in
            isLoading = false
            if case .failure(let error) = result {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct SignInView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var authState: AuthState
    
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
                    
                    // Semi-transparent overlay
                    Color.black.opacity(0.7)
                        .edgesIgnoringSafeArea(.all)
                    
                    // Original ZStack content
                    ScrollView {
                        VStack {
                            // Add explicit spacing at the top
                            Spacer()
                                .frame(height: geometry.safeAreaInsets.top + 16)
                                
                            // Title with proper spacing
                            Text("Sign In")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.top, 24)
                                .padding(.bottom, 36)
                            
                            VStack(spacing: 24) { // Increased spacing between form fields
                                TextField("Email", text: $email)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .textContentType(.emailAddress)
                                    .autocapitalization(.none)
                                    .font(.system(size: 16))
                                    .padding(.vertical, 8) // Added padding
                                
                                SecureField("Password", text: $password)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .textContentType(.password)
                                    .font(.system(size: 16))
                                    .padding(.vertical, 8) // Added padding
                            }
                            .padding(.horizontal, 30)
                            
                            Spacer(minLength: 40)
                            
                            // Bottom button - ensure it stays visible
                            Button(action: performSignIn) {
                                ZStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(1.2)
                                    } else {
                                        Text("Sign In")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 55)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .cornerRadius(25)
                            .padding(.horizontal, 30)
                            .padding(.top, 20)
                            .padding(.bottom, max(30, geometry.safeAreaInsets.bottom + 30))
                            .disabled(isLoading || email.isEmpty || password.isEmpty)
                            .frame(maxWidth: 400)
                        }
                        .frame(minHeight: geometry.size.height) // Ensure scrollable area fills screen
                    }
                }
            }
            .navigationBarTitle("", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { isPresented = false }
                        .padding(.vertical, 8) // Increase tap target
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .fixInputAssistantHeight() // Apply custom input view fix
    }
    
    private func performSignIn() {
        isLoading = true
        authState.signIn(email: email, password: password) { result in
            isLoading = false
            switch result {
            case .success(_):
                isPresented = false
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct SignUpView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var authState: AuthState
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }
    
    var isValid: Bool {
        !email.isEmpty && passwordsMatch
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack { // Outer ZStack for background
                    // Background Image
                    Image("welcome_background")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .edgesIgnoringSafeArea(.all)
                    
                    // Semi-transparent overlay
                    Color.black.opacity(0.7)
                        .edgesIgnoringSafeArea(.all)
                        
                    // Original ZStack content
                    ScrollView {
                        VStack {
                            // Add explicit spacing at the top
                            Spacer()
                                .frame(height: geometry.safeAreaInsets.top + 16)
                                
                            // Title with proper spacing
                            Text("Create Account")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.top, 24)
                                .padding(.bottom, 36)
                            
                            VStack(spacing: 24) { // Increased spacing between form fields
                                TextField("Email", text: $email)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .textContentType(.emailAddress)
                                    .autocapitalization(.none)
                                    .font(.system(size: 16))
                                    .padding(.vertical, 8) // Added padding
                                
                                SecureField("Password", text: $password)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .textContentType(.newPassword)
                                    .font(.system(size: 16))
                                    .padding(.vertical, 8) // Added padding
                                
                                SecureField("Confirm Password", text: $confirmPassword)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .textContentType(.newPassword)
                                    .font(.system(size: 16))
                                    .padding(.vertical, 8) // Added padding
                            }
                            .padding(.horizontal, 30)
                            
                            Spacer(minLength: 40)
                            
                            // Password matching indicator
                            if !password.isEmpty && !confirmPassword.isEmpty {
                                HStack {
                                    Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(passwordsMatch ? .green : .red)
                                    Text(passwordsMatch ? "Passwords match" : "Passwords don't match")
                                        .font(.callout)
                                        .foregroundColor(passwordsMatch ? .green : .red)
                                }
                                .padding(.top, 10)
                            }
                            
                            // Bottom button
                            Button(action: performSignUp) {
                                ZStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(1.2)
                                    } else {
                                        Text("Create Account")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 55)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .cornerRadius(25)
                            .padding(.horizontal, 30)
                            .padding(.top, 20)
                            .padding(.bottom, max(30, geometry.safeAreaInsets.bottom + 30))
                            .disabled(isLoading || !isValid)
                            .frame(maxWidth: 400)
                        }
                        .frame(minHeight: geometry.size.height) // Ensure scrollable area fills screen
                    }
                }
            }
            .navigationBarTitle("", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { isPresented = false }
                        .padding(.vertical, 8) // Increase tap target
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .fixInputAssistantHeight() // Apply custom input view fix
    }
    
    private func performSignUp() {
        guard passwordsMatch else {
            errorMessage = "Passwords do not match."
            showError = true
            return
        }
        
        isLoading = true
        authState.signUp(email: email, password: password) { result in
            isLoading = false
            switch result {
            case .success(_):
                isPresented = false
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
            .environmentObject(AuthState.shared)
            .environmentObject(NetworkMonitor())
    }
}