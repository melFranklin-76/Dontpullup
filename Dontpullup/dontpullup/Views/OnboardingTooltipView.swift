import SwiftUI
import UIKit

struct OnboardingTooltipView: View {
    let step: OnboardingStep
    let onNext: () -> Void
    let onSkip: () -> Void
    
    @State private var isAnimating = false
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    // Adapt to screen size
    private var adaptiveMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 280 : 250
    }
    
    // Adapt padding to screen size
    private var adaptivePadding: CGFloat {
        horizontalSizeClass == .regular ? 16 : 12
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: adaptivePadding) {
            // Title
            Text(step.title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Description
            Text(step.description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(4) // Limit height with line limit
            
            // Buttons
            HStack(spacing: 16) {
                if step != .welcome {
                    Button(action: onSkip) {
                        Text("Skip")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(12)
                }
                
                Spacer()
                
                Button(action: onNext) {
                    Text(step == OnboardingStep.allCases[OnboardingStep.allCases.count - 2] ? "Finish" : "Next")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.red)
                .cornerRadius(12)
            }
        }
        .padding(adaptivePadding)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 5)
        .frame(maxWidth: adaptiveMaxWidth) // Responsive width
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                isAnimating = true
            }
        }
        .scaleEffect(isAnimating ? 1.0 : 0.8)
        .opacity(isAnimating ? 1.0 : 0)
    }
}

// View modifier to create a tooltip overlay for any view
struct TooltipModifier: ViewModifier {
    @ObservedObject var onboardingManager = OnboardingManager.shared
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if onboardingManager.isShowingTooltip {
                GeometryReader { geometry in
                    ZStack(alignment: .center) {
                        // Semi-transparent overlay behind tooltip
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                            .onTapGesture {
                                // Optional: tap background to advance
                                // onboardingManager.nextStep()
                            }
                        
                        // The tooltip
                        tooltipContent
                            .position(getTooltipPosition(in: geometry))
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var tooltipContent: some View {
        OnboardingTooltipView(
            step: onboardingManager.currentStep,
            onNext: {
                onboardingManager.nextStep()
            },
            onSkip: {
                onboardingManager.skipOnboarding()
            }
        )
    }
    
    private func getTooltipPosition(in geometry: GeometryProxy) -> CGPoint {
        let step = onboardingManager.currentStep
        let deviceType = UIDevice.current.userInterfaceIdiom
        let isPortrait = geometry.size.height > geometry.size.width
        
        // Adjust screen positions based on device type and orientation
        if let screenPos = step.screenPosition {
            // Convert relative positions (0.0-1.0) to actual screen coordinates
            var x = geometry.size.width * CGFloat(screenPos.x)
            var y = geometry.size.height * CGFloat(screenPos.y)
            
            // Device-specific adjustments
            switch deviceType {
            case .phone:
                if isPortrait {
                    // iPhone portrait adjustments
                    if step == .profile {
                        // Move profile tooltip more to the left on small phones
                        if geometry.size.width < 390 { // smaller iPhones
                            x = geometry.size.width * 0.65
                        }
                        // Adjust vertical position based on notch/dynamic island
                        y = min(y, geometry.size.height - 120)
                    }
                } else {
                    // iPhone landscape adjustments
                    if step == .filters {
                        // Move filters more to the center in landscape
                        x = geometry.size.width * 0.6
                    }
                }
            case .pad:
                // iPad-specific positioning
                if step == .profile {
                    // Move profile tooltip more to center on iPads
                    x = geometry.size.width * 0.65
                }
            default:
                break
            }
            
            // Apply safe area adjustments
            let safeTop = geometry.safeAreaInsets.top
            let safeBottom = geometry.safeAreaInsets.bottom
            let safeLeft = geometry.safeAreaInsets.leading
            let safeRight = geometry.safeAreaInsets.trailing
            
            // Get tooltip dimensions (approximate)
            let tooltipWidth: CGFloat = deviceType == .pad ? 280 : 250
            let tooltipHeight: CGFloat = 150
            
            // Ensure tooltip stays within safe area plus additional padding
            let padding: CGFloat = 10
            let minX = safeLeft + padding + tooltipWidth/2
            let maxX = geometry.size.width - safeRight - padding - tooltipWidth/2
            let minY = safeTop + padding + tooltipHeight/2
            let maxY = geometry.size.height - safeBottom - padding - tooltipHeight/2
            
            // Clamp to safe boundaries
            x = min(max(x, minX), maxX)
            y = min(max(y, minY), maxY)
            
            return CGPoint(x: x, y: y)
        }
        
        // For steps with a specific target view
        let targetTag = step.targetViewTag
        if targetTag != 0, let targetFrame = findTargetViewFrame(with: targetTag, in: geometry) {
            return adjustTooltipPositionRelativeToTarget(targetFrame: targetFrame, in: geometry)
        }
        
        // Default center position for steps without a specific target
        return CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
    }
    
    private func findTargetViewFrame(with tag: Int, in geometry: GeometryProxy) -> CGRect? {
        // These positions are based on the actual UI layout of your app
        // Adjusted to better match real positions
        let size = geometry.size
        let safeAreaBottom = geometry.safeAreaInsets.bottom + 10
        let isPortrait = size.height > size.width
        
        // Adjust target frame based on device orientation
        switch tag {
        case 100: // Location button (center bottom)
            if isPortrait {
                return CGRect(
                    x: size.width / 2, 
                    y: size.height - 60 - safeAreaBottom, 
                    width: 50, 
                    height: 50
                )
            } else {
                // In landscape, adjust for different layout
                return CGRect(
                    x: size.width / 2,
                    y: size.height - 45 - safeAreaBottom,
                    width: 50,
                    height: 50
                )
            }
        case 101: // Filter buttons (right side)
            if isPortrait {
                return CGRect(
                    x: size.width - 50, 
                    y: size.height / 2 - 100, 
                    width: 50, 
                    height: 150
                )
            } else {
                // In landscape, adjust for different layout
                return CGRect(
                    x: size.width - 50,
                    y: size.height / 2,
                    width: 50,
                    height: 120
                )
            }
        case 102: // Profile button (bottom right)
            if isPortrait {
                return CGRect(
                    x: size.width - 50, 
                    y: size.height - 60 - safeAreaBottom,
                    width: 50, 
                    height: 50
                )
            } else {
                // In landscape, adjust for different layout
                return CGRect(
                    x: size.width - 50,
                    y: size.height - 45 - safeAreaBottom,
                    width: 50,
                    height: 50
                )
            }
        default:
            return nil
        }
    }
    
    private func adjustTooltipPositionRelativeToTarget(targetFrame: CGRect, in geometry: GeometryProxy) -> CGPoint {
        let step = onboardingManager.currentStep
        let deviceType = UIDevice.current.userInterfaceIdiom
        
        // Calculate tooltip size (approximate)
        let tooltipWidth: CGFloat = deviceType == .pad ? 280 : 250
        let tooltipHeight: CGFloat = 150
        
        // Base position calculation on anchor point
        var position: CGPoint
        
        switch step.targetAnchor {
        case .leading:
            position = CGPoint(
                x: targetFrame.minX - tooltipWidth/2 - 10,
                y: targetFrame.midY
            )
        case .trailing:
            position = CGPoint(
                x: targetFrame.maxX + tooltipWidth/2 + 10,
                y: targetFrame.midY
            )
        case .top:
            position = CGPoint(
                x: targetFrame.midX,
                y: targetFrame.minY - tooltipHeight/2 - 10
            )
        case .bottom:
            position = CGPoint(
                x: targetFrame.midX,
                y: targetFrame.maxY + tooltipHeight/2 + 10
            )
        default:
            // For .center or any other case, position in middle of the screen
            position = CGPoint(x: geometry.size.width/2, y: geometry.size.height/2)
        }
        
        // Ensure tooltip stays within screen bounds
        // Keep distance from edges including safe area
        let safeTop = geometry.safeAreaInsets.top
        let safeBottom = geometry.safeAreaInsets.bottom
        let safeLeft = geometry.safeAreaInsets.leading
        let safeRight = geometry.safeAreaInsets.trailing
        
        let padding: CGFloat = 10
        let minX = safeLeft + padding + tooltipWidth/2
        let maxX = geometry.size.width - safeRight - padding - tooltipWidth/2
        let minY = safeTop + padding + tooltipHeight/2
        let maxY = geometry.size.height - safeBottom - padding - tooltipHeight/2
        
        // Clamp position to screen bounds
        position.x = min(max(position.x, minX), maxX)
        position.y = min(max(position.y, minY), maxY)
        
        return position
    }
}

// Extension to apply the tooltip modifier to any View
extension View {
    func withOnboardingTooltips() -> some View {
        self.modifier(TooltipModifier())
    }
}

// Preview for the tooltip
struct OnboardingTooltipView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray
                .edgesIgnoringSafeArea(.all)
            
            OnboardingTooltipView(
                step: .welcome,
                onNext: {},
                onSkip: {}
            )
        }
    }
} 