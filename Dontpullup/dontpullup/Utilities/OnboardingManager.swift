import SwiftUI
import Combine

// Define onboarding steps
enum OnboardingStep: Int, CaseIterable {
    case welcome
    case mapExploration
    case dropPin
    case filters
    case profile
    case finished
    
    var title: String {
        switch self {
        case .welcome: return "Welcome to Don't Pull Up"
        case .mapExploration: return "Explore the Map"
        case .dropPin: return "Drop a Pin"
        case .filters: return "Filter Incidents"
        case .profile: return "Your Profile"
        case .finished: return ""
        }
    }
    
    var description: String {
        switch self {
        case .welcome: return "See what's happening in your area. Long press on the map to report an incident."
        case .mapExploration: return "Tap this button to center the map on your location."
        case .dropPin: return "Long press anywhere on the map to drop a pin and upload a video."
        case .filters: return "Use these buttons to filter incidents by type."
        case .profile: return "Access your profile and settings here."
        case .finished: return ""
        }
    }
    
    // Coordinates for tooltip arrow pointing to UI element
    var targetAnchor: UnitPoint {
        switch self {
        case .welcome: return .center
        case .mapExploration: return .top
        case .dropPin: return .center
        case .filters: return .trailing
        case .profile: return .top
        case .finished: return .center
        }
    }
    
    // Each tooltip points to a specific UI element
    var targetViewTag: Int {
        switch self {
        case .welcome: return 0
        case .mapExploration: return 100 // Tag for location button
        case .dropPin: return 0
        case .filters: return 101 // Tag for filter buttons
        case .profile: return 102 // Tag for profile button
        case .finished: return 0
        }
    }
    
    // Position on screen - manually adjusted for ideal placement
    var screenPosition: (x: Double, y: Double)? {
        switch self {
        case .welcome: 
            return nil // Center of screen
        case .mapExploration:
            return (0.5, 0.60) // Middle of screen, slightly above bottom
        case .dropPin:
            return (0.5, 0.4) // Middle of screen, slightly above center
        case .filters:
            return (0.7, 0.4) // Right side of screen, vertically centered
        case .profile:
            return (0.75, 0.65) // Adjusted: More toward center and up from bottom
        case .finished:
            return nil
        }
    }
}

// Main onboarding manager class
class OnboardingManager: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var isShowingTooltip = false
    @Published var hasCompletedOnboarding = false
    
    private var cancellables = Set<AnyCancellable>()
    
    // Singleton instance for easy access
    static let shared = OnboardingManager()
    
    private init() {
        // Load onboarding status from UserDefaults
        let defaults = UserDefaults.standard
        hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
        
        // Setup publisher to save state when onboarding completes
        $hasCompletedOnboarding
            .dropFirst()
            .sink { completed in
                UserDefaults.standard.set(completed, forKey: "hasCompletedOnboarding")
            }
            .store(in: &cancellables)
    }
    
    func startOnboarding() {
        guard !hasCompletedOnboarding else { return }
        
        currentStep = .welcome
        isShowingTooltip = true
    }
    
    func nextStep() {
        let allSteps = OnboardingStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentStep),
              currentIndex < allSteps.count - 1 else {
            completeOnboarding()
            return
        }
        
        currentStep = allSteps[currentIndex + 1]
        
        // If we're at the finished step, complete onboarding
        if currentStep == .finished {
            completeOnboarding()
        }
    }
    
    func skipOnboarding() {
        completeOnboarding()
    }
    
    private func completeOnboarding() {
        isShowingTooltip = false
        hasCompletedOnboarding = true
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
    }
} 