import SwiftUI

struct RootView: View {
    @EnvironmentObject var authState: AuthState
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @State private var showInstructions = false

    var body: some View {
        Group {
            if authState.isLoading {
                SplashScreen()
                    .onAppear { print("[RootView] SplashScreen appeared") }
                    .onDisappear { print("[RootView] SplashScreen disappeared") }
            } else {
                Group {
                    if authState.isAuthenticated {
                        MainTabView()
                            .id("MainTabView_\(authState.isAuthenticated)_\(authState.currentUser?.uid ?? "none")_anon:\(authState.isAnonymous)")
                            .onAppear {
                                if authState.isAnonymous {
                                    print("[RootView] Showing MainTabView for ANONYMOUS authenticated user")
                                } else {
                                    print("[RootView] Showing MainTabView because isAuthenticated is TRUE and isAnonymous is FALSE")
                                }
                                // Check if we should show instructions
                                showInstructions = authState.shouldShowInstructions
                            }
                            .sheet(isPresented: $showInstructions) {
                                DetailedInstructionsView()
                                    .onDisappear {
                                        authState.dismissInstructions()
                                        showInstructions = false
                                    }
                            }
                    } else {
                        AuthView()
                            .id("AuthView_unauthenticated")
                            .onAppear {
                                print("[RootView] Showing AuthView because isAuthenticated is FALSE")
                            }
                    }
                }
            }
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
    }
} 
