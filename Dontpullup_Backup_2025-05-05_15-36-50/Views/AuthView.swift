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
                    // Top section with title
                    Spacer().frame(height: geometry.safeAreaInsets.top + 20)
                    
                    // Middle section with tagline
                    Text("Show us who they are\nso we can show them who we not")
                        .font(.custom("BlackOpsOne-Regular", size: 20))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.5), radius: 3)
                        .padding(.horizontal, 10)
                        .padding(.top, 40)
                    
                    Spacer()
                    
                    // Bottom section with buttons
                    VStack(spacing: 16) {
                        Button(action: { isShowingSignIn = true }) {
                            Text("Sign In")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .frame(height: 50)
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
                                .frame(height: 50)
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
                        .padding(.top, 8)
                    }
                    .padding(.bottom, max(20, 40))
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

// Rename LoginView to SignInView and update its structure
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
                    ZStack {
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
                                
                                // Bottom button - ensure it stays visible
                                Button(action: performSignIn) {
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
                                .tint(.blue)
                                .cornerRadius(25)
                                .padding(.horizontal, 24)
                                .padding(.bottom, max(20, geometry.safeAreaInsets.bottom + 20))
                                .disabled(isLoading || email.isEmpty || password.isEmpty)
                                .frame(maxWidth: 400)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
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

// Rename RegisterView to SignUpView and update its structure
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
                    ZStack {
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
                                
                                // Bottom button
                                Button(action: performSignUp) {
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
                                .padding(.bottom, max(20, geometry.safeAreaInsets.bottom + 20))
                                .disabled(isLoading || !isValid)
                                .frame(maxWidth: 400)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
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