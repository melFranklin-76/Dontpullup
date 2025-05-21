import SwiftUI
import FirebaseAuth
import Network

// MARK: - Auth Background Modifier

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

// MARK: - Main Auth View

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
                    
                    // Middle section with tagline and improved spacing
                    Text("Show us who they  are   so we can    show them who we not")
                        .font(.custom("BlackOpsOne-Regular", size: 21))
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
        Task {
            do {
                try await authState.signInAnonymouslyAsync()
                isLoading = false
                // Success will be handled by AuthState listener
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Sign In View

struct SignInView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var authState: AuthState
    @State private var showProgressOverlay = false
    
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
                                    .keyboardType(.emailAddress)
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
                    
                    // Progress overlay
                    if showProgressOverlay {
                        Color.black.opacity(0.5)
                            .edgesIgnoringSafeArea(.all)
                            .overlay(
                                VStack(spacing: 20) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.5)
                                    
                                    Text("Signing in...")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                .padding(30)
                                .background(Color(.systemGray6).opacity(0.7))
                                .cornerRadius(15)
                            )
                            .transition(.opacity)
                            .zIndex(100)
                    }
                }
                .dismissKeyboardOnTapGesture() // Use our new method
            }
            .navigationBarTitle("", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { isPresented = false }
                        .padding(.vertical, 8) // Increase tap target
                        .foregroundColor(.white)
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
        .withKeyboardDismissButton() // Use our new keyboard dismiss button
    }
    
    private func performSignIn() {
        // Show loading state
        isLoading = true
        showProgressOverlay = true
        
        // Dismiss keyboard first to avoid constraints issues
        UIPlatformHelper.dismissKeyboard()
        
        Task {
            do {
                let authResult = try await authState.signInAsync(email: email, password: password)
                print("Successfully signed in: \(authResult.uid)")
                
                // Small delay to ensure state has time to update
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                DispatchQueue.main.async {
                    isLoading = false
                    showProgressOverlay = false
                    isPresented = false
                }
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    showProgressOverlay = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Custom ZipCode TextField with NumberPad Done Button

struct ZipCodeTextField: View {
    @Binding var text: String
    
    var body: some View {
        VStack {
            TextField("Zip Code", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
                .font(.system(size: 16))
                .padding(.vertical, 8)
                .onChange(of: text) { newValue in
                    // Limit to 5 digits and numbers only
                    let filtered = newValue.filter { "0123456789".contains($0) }
                    if filtered != newValue {
                        text = filtered
                    }
                    if filtered.count > 5 {
                        text = String(filtered.prefix(5))
                    }
                }
        }
        .overlay(
            // Add a custom done button for number pad that's more reliable
            VStack {
                #if canImport(UIKit)
                if UIResponder.isFirstResponderTextField() {
                    HStack {
                        Spacer()
                        Button(action: {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }) {
                            Text("Done")
                                .bold()
                                .foregroundColor(.blue)
                                .padding(12) // Larger tap target
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(8)
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                .padding(5)
                        }
                    }
                    .padding(.trailing, 10)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: UIResponder.isFirstResponderTextField())
                }
                #endif
                Spacer()
            }
        )
    }
}

// Extension to check if keyboard is shown
extension UIResponder {
    static var currentFirstResponder: UIResponder?
    
    static func isFirstResponderTextField() -> Bool {
        #if canImport(UIKit)
        return currentFirstResponder is UITextField
        #else
        return false
        #endif
    }
    
    static func findFirstResponder(in view: UIView) -> UIResponder? {
        #if canImport(UIKit)
        for subview in view.subviews {
            if subview.isFirstResponder {
                return subview
            }
            
            if let responder = findFirstResponder(in: subview) {
                return responder
            }
        }
        #endif
        return nil
    }
}

// MARK: - Sign Up View

struct SignUpView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var authState: AuthState
    @State private var showProgressOverlay = false
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var zipCode = ""
    
    var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }
    
    var isValid: Bool {
        !email.isEmpty && passwordsMatch && zipCode.count == 5 && zipCode.allSatisfy("0123456789".contains)
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
                                    .keyboardType(.emailAddress)
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
                                
                                // Replace standard TextField with custom ZipCodeTextField
                                ZipCodeTextField(text: $zipCode)
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
                    
                    // Progress overlay
                    if showProgressOverlay {
                        Color.black.opacity(0.5)
                            .edgesIgnoringSafeArea(.all)
                            .overlay(
                                VStack(spacing: 20) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.5)
                                    
                                    Text("Creating account...")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                .padding(30)
                                .background(Color(.systemGray6).opacity(0.7))
                                .cornerRadius(15)
                            )
                            .transition(.opacity)
                            .zIndex(100)
                    }
                }
                .dismissKeyboardOnTapGesture() // Use our new method
            }
            .navigationBarTitle("", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { isPresented = false }
                        .padding(.vertical, 8) // Increase tap target
                        .foregroundColor(.white)
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
        .withKeyboardDismissButton() // Use our new keyboard dismiss button
    }
    
    private func performSignUp() {
        guard passwordsMatch else {
            errorMessage = "Passwords do not match."
            showError = true
            return
        }
        guard zipCode.count == 5 && zipCode.allSatisfy("0123456789".contains) else {
            errorMessage = "Please enter a valid 5-digit zip code."
            showError = true
            return
        }
        
        // Show loading state
        isLoading = true
        showProgressOverlay = true
        
        // Dismiss keyboard first to avoid constraints issues
        UIPlatformHelper.dismissKeyboard()
        
        Task {
            do {
                let authResult = try await authState.signUpAsync(email: email, password: password, zipCode: zipCode)
                print("Successfully signed up: \(authResult.uid)")
                
                // Small delay to ensure state has time to update
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                DispatchQueue.main.async {
                    isLoading = false
                    showProgressOverlay = false
                    isPresented = false
                }
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    showProgressOverlay = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Simple Auth State View

struct AuthStateView: View {
    @StateObject private var viewModel = UserAuthViewModel()
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Signing in...")
            } else {
                Text("Welcome to Don't Pull Up")
                    .font(.title)
                    .padding()
                
                Button("Continue as Guest") {
                    Task {
                        do {
                            try await viewModel.signInAnonymously()
                            // Authentication success is handled by the AuthState listener
                        } catch {
                            // Error is handled in the view model through alerts
                            print("Anonymous sign-in failed: \(error.localizedDescription)")
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .alert("Error", isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
    }
} 
