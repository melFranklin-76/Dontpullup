import SwiftUI

struct RootView: View {
    @EnvironmentObject var authState: AuthState // Use the injected AuthState
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    // @State private var showInstructions = false // Temporarily commented out

    var body: some View {
        let isAuthenticated = authState.isAuthenticated
        let isAnonymous = authState.isAnonymous

        Group { // Outer group
            if authState.isLoading {
                SplashScreen()
                    .onAppear { print("[RootView] SplashScreen appeared") }
                    .onDisappear { print("[RootView] SplashScreen disappeared") }
            } else {
                // Restore the original logic for showing AuthView or MainTabView

                Group { // Inner group wrapping conditionals
                    if isAuthenticated { // Simplified condition: if authenticated (anonymous or not), show MainTabView
                        MainTabView()
                            .id("MainTabView_\(authState.isAuthenticated)_\(authState.currentUser?.uid ?? "none")_anon:\(authState.isAnonymous)") // Adjusted ID to reflect anon status
                            .onAppear {
                                if authState.isAnonymous {
                                    print("[RootView] Showing MainTabView for ANONYMOUS authenticated user")
                                } else {
                                    print("[RootView] Showing MainTabView because isAuthenticated is TRUE and isAnonymous is FALSE")
                                }
                                // showInstructions = authState.shouldShowInstructions // Keep this commented for now
                            }
                            // .onDisappear { print("[RootView] MainTabView disappeared") } // Keep commented
                            // .fullScreenCover(isPresented: $showInstructions) { ... } // Keep commented
                    } else { // Not authenticated
                        AuthView()
                            .id("AuthView_unauthenticated") // Simplified ID
                            .onAppear {
                                print("[RootView] Showing AuthView because isAuthenticated is FALSE")
                            }
                            // .onDisappear { print("[RootView] AuthView (for unauth) disappeared") } // Keep commented
                    }
                } // End of inner Group
                // print("[RootView] Evaluating body state. isLoading: \\(authState.isLoading), isAuthenticated: \\(authState.isAuthenticated), isAnonymous: \\(authState.isAnonymous), currentUser: \\(authState.currentUser?.uid ?? "nil"))")
                // print("[RootView] Decision Point: isAuthenticated=\\(isAuthenticated), isAnonymous=\\(isAnonymous) after isLoading is false.")
            } // THIS IS THE ELSE BLOCK'S CLOSING BRACE
        }
        .onAppear { 
            print("[RootView] Evaluating body state. isLoading: \(authState.isLoading), isAuthenticated: \(authState.isAuthenticated), isAnonymous: \(authState.isAnonymous), currentUser: \(authState.currentUser?.uid ?? "nil"))")
        }
        .overlay {
            if !networkMonitor.isConnected {
                VStack {
                    Spacer()
                    Text("No Internet Connection")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(8)
                        .padding(.bottom, 20)
                }
            }
        }
        // Original full body commented out below for reference if needed
        /*
        Text("Hello from RootView")
            .onAppear { print("[RootView DEBUG] Simple Text view appeared.") }
        */

        // Further original logic also commented out
        /*
        let _ = print("[RootView] Evaluating body state. isLoading: \(authState.isLoading), isAuthenticated: \(authState.isAuthenticated), isAnonymous: \(authState.isAnonymous), currentUser: \(authState.currentUser?.uid ?? "nil")")
        Group { // Outer group
            if authState.isLoading {
                SplashScreen()
                    .onAppear { print("[RootView] SplashScreen appeared") }
                    .onDisappear { print("[RootView] SplashScreen disappeared") }
            } else {
                // TEMPORARY DEBUGGING: Force AuthView to always be chosen
                print("[RootView DEBUG] Forcing AuthView directly after SplashScreen.")
                AuthView()
                    .onAppear { print("[RootView DEBUG] Forced AuthView .onAppear triggered.") }
                // END TEMPORARY DEBUGGING

                // Original logic commented out:
                /*
                let isAuthenticated = authState.isAuthenticated
                let isAnonymous = authState.isAnonymous
                // Decision point print moved to Group's .onAppear below

                Group { // Inner group wrapping conditionals
                    if isAuthenticated && !isAnonymous {
                        MainTabView()
                            .id("MainTabView_\(authState.isAuthenticated)_\(authState.currentUser?.uid ?? \"none\")") // Re-add .id
                            .onAppear { // Print moved here
                                print("[RootView] Showing MainTabView because isAuthenticated is TRUE and isAnonymous is FALSE")
                                // showInstructions = authState.shouldShowInstructions // Keep this commented for now
                            }
                            // .onDisappear { print("[RootView] MainTabView disappeared") } // Keep commented
                            // .fullScreenCover(isPresented: $showInstructions) { ... } // Keep commented
                    } else if isAuthenticated && isAnonymous {
                        AuthView()
                            .id("AuthView_\(authState.isAuthenticated)_anon") // Re-add .id
                            .onAppear { // Print moved here
                                print("[RootView] Showing AuthView because isAuthenticated is TRUE but isAnonymous is also TRUE (Anonymous User)")
                            }
                            // .onDisappear { print("[RootView] AuthView (for anon) disappeared") } // Keep commented
                    } else { // Not authenticated
                        AuthView()
                            .id("AuthView_\(authState.isAuthenticated)_unauth") // Re-add .id
                            .onAppear { // Print moved here
                                print("[RootView] Showing AuthView because isAuthenticated is FALSE")
                            }
                            // .onDisappear { print("[RootView] AuthView (for unauth) disappeared") } // Keep commented
                    }
                } // End of inner Group
                .onAppear { // Decision point print here
                     print("[RootView] Decision Point: isAuthenticated=\(isAuthenticated), isAnonymous=\(isAnonymous)")
                }
                */
            }
        }
        .onAppear { // Moved print for body evaluation here
            print("[RootView] Evaluating body state. isLoading: \(authState.isLoading), isAuthenticated: \(authState.isAuthenticated), isAnonymous: \(authState.isAnonymous), currentUser: \(authState.currentUser?.uid ?? "nil")")
        }
        .overlay {
            if !networkMonitor.isConnected {
                VStack {
                    Spacer()
                    Text("No Internet Connection")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(8)
                        .padding(.bottom, 20)
                }
            }
        }
        */
    }

    // Original authenticatedView commented out
    /*
    @ViewBuilder
    private var authenticatedView: some View {
        let isAuthenticated = authState.isAuthenticated
        let isAnonymous = authState.isAnonymous
        print("[RootView] Decision Point: isAuthenticated=\(isAuthenticated), isAnonymous=\(isAnonymous)")

        Group {
            if isAuthenticated && !isAnonymous {
                print("[RootView] Showing MainTabView because isAuthenticated is TRUE and isAnonymous is FALSE")
                MainTabView()
                    // Modifiers temporarily removed for build testing
                    // .id("MainTabView_\(authState.isAuthenticated)_\(authState.currentUser?.uid ?? \"none\")")
                    // .onAppear { // Print moved here
                    //     print("[RootView] Showing MainTabView because isAuthenticated is TRUE and isAnonymous is FALSE")
                    //     // showInstructions = authState.shouldShowInstructions
                    // }
                    // .onDisappear { print("[RootView] MainTabView disappeared") }
                    // .fullScreenCover(isPresented: $showInstructions) { // << Still commented out
                    //     TutorialViewControllerRepresentable {
                    //         authState.dismissInstructions()
                    //         showInstructions = false
                    //     }
                    // }
            } else if isAuthenticated && isAnonymous {
                print("[RootView] Showing AuthView because isAuthenticated is TRUE but isAnonymous is also TRUE (Anonymous User)")
                AuthView()
                    // Modifiers temporarily removed for build testing
                    // .id("AuthView_\(authState.isAuthenticated)_anon") 
                    // .onAppear { // Print moved here
                    //     print("[RootView] Showing AuthView because isAuthenticated is TRUE but isAnonymous is also TRUE (Anonymous User)")
                    // }
                    // .onDisappear { print("[RootView] AuthView (for anon) disappeared") }
            } else { // Not authenticated
                print("[RootView] Showing AuthView because isAuthenticated is FALSE")
                AuthView()
                    // Modifiers temporarily removed for build testing
                    // .id("AuthView_\(authState.isAuthenticated)_unauth") 
                    // .onAppear { // Print moved here
                    //     print("[RootView] Showing AuthView because isAuthenticated is FALSE")
                    // }
                    // .onDisappear { print("[RootView] AuthView (for unauth) disappeared") }
            }
        } // End of inner Group
        .onAppear { // Moved decision point print here
             print("[RootView] Decision Point: isAuthenticated=\(isAuthenticated), isAnonymous=\(isAnonymous)")
        }
    }
    */
}


// Add a simple instructions view
struct InstructionsView: View {
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Don't Pull Up")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.top, 40)
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 16) {
                InstructionRow(
                    icon: "mappin.and.ellipse",
                    title: "Report Incidents",
                    description: "Long press on the map to place a pin and report an incident"
                )
                
                InstructionRow(
                    icon: "video.fill",
                    title: "Upload Videos",
                    description: "Add video evidence when reporting incidents"
                )
                
                InstructionRow(
                    icon: "location.fill",
                    title: "Find Your Location",
                    description: "Tap the location button to center the map on your current position"
                )
                
                InstructionRow(
                    icon: "exclamationmark.triangle.fill",
                    title: "Emergency Reporting",
                    description: "Use the emergency option for urgent situations requiring immediate attention"
                )
            }
            .padding()
            
            Spacer()
            
            Button(action: onDismiss) {
                Text("Got It")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 40)
        }
    }
}

struct InstructionRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
} 
