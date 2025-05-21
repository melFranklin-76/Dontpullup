import SwiftUI
import UIKit

// MARK: - Helper Extension for Layout Constraints

extension NSLayoutConstraint {
    /// Sets the priority for a constraint and returns it
    func withPriority(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}

// MARK: - Tutorial Overlay View for SwiftUI Integration

/// Tutorial overlay view that guides users through the app features
struct TutorialOverlayView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var currentStep: Int
    let totalSteps = 5
    
    // Tutorial content for each step
    let tutorialContent: [(title: String, description: String, icon: String)] = [
        (
            title: "Welcome to Don't Pull Up 👋",
            description: "A community-driven app to document and share incidents in your area",
            icon: "hand.wave.fill"
        ),
        (
            title: "Drop Pins 📍",
            description: "Long press on the map to drop a pin within 200 feet of your location",
            icon: "mappin.and.ellipse"
        ),
        (
            title: "Add Videos 📹",
            description: "Share video evidence (up to 3 minutes) of incidents to help others stay informed",
            icon: "video.fill"
        ),
        (
            title: "Incident Types",
            description: "Report different incidents: Verbal 🗣️, Physical 👊, or Emergency 🚨",
            icon: "exclamationmark.triangle.fill"
        ),
        (
            title: "Ready To Go! ✅",
            description: "You're all set to use Don't Pull Up. Tap 'Get Started' to begin.",
            icon: "checkmark.circle.fill"
        )
    ]
    
    var body: some View {
        ZStack {
            // Semi-transparent black background
            Color.black.opacity(0.85)
                .edgesIgnoringSafeArea(.all)
            
            // Tutorial content
            VStack(spacing: 40) {
                Spacer()
                
                // Icon for current step
                Image(systemName: tutorialContent[currentStep].icon)
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .padding(.bottom, 20)
                
                // Title for current step
                Text(tutorialContent[currentStep].title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                // Description for current step
                Text(tutorialContent[currentStep].description)
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                // Progress indicators
                HStack(spacing: 10) {
                    ForEach(0..<totalSteps, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? Color.white : Color.gray.opacity(0.5))
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.bottom, 20)
                
                // Navigation buttons
                HStack(spacing: 40) {
                    // Back button (hidden on first step)
                    Button(action: {
                        if currentStep > 0 {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                    }) {
                        Text("Back")
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(currentStep > 0 ? Color.blue.opacity(0.5) : Color.clear)
                            .cornerRadius(8)
                    }
                    .opacity(currentStep > 0 ? 1.0 : 0.0)
                    
                    // Next/Finish button
                    Button(action: {
                        if currentStep < totalSteps - 1 {
                            withAnimation {
                                currentStep += 1
                            }
                        } else {
                            // On last step, dismiss the tutorial
                            dismiss()
                        }
                    }) {
                        Text(currentStep < totalSteps - 1 ? "Next" : "Get Started")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .transition(.opacity)
        .animation(.easeInOut, value: currentStep)
    }
}

// MARK: - UIKit Tutorial View Controller for Modal Presentation

/// UIKit-based tutorial view controller for guaranteed presentation
class TutorialViewController: UIViewController {
    // Callback for when the tutorial is dismissed
    private var dismissCallback: (() -> Void)?
    
    // Tutorial pages content
    private let pages = [
        (image: "mappin.and.ellipse", title: "Report Incidents 📍", message: "Long press on the map to place a pin and report an incident within 200 feet of your location"),
        (image: "video.fill", title: "Upload Videos 📹", message: "Add video evidence (up to 3 minutes) when reporting incidents"),
        (image: "exclamationmark.triangle.fill", title: "Incident Types", message: "Choose from: Verbal 🗣️, Physical 👊, or Emergency 🚨 incidents"),
        (image: "location.fill", title: "Find Your Location 📍", message: "Tap the location button to center the map on your position and see the 200-foot range"),
        (image: "iphone", title: "Manage Your Content 📱", message: "Tap the phone icon to filter and see only your pins. Use edit mode ✏️ to delete pins.")
    ]
    
    // Current tutorial page index
    private var currentPage = 0
    
    // UI elements
    private var containerView: UIView!
    private var iconView: UIImageView!
    private var titleLabel: UILabel!
    private var messageLabel: UILabel!
    private var pageControl: UIPageControl!
    private var nextButton: UIButton!
    private var skipButton: UIButton!
    
    // Initialize with completion handler
    init(dismissCallback: (() -> Void)? = nil) {
        self.dismissCallback = dismissCallback
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateContent(forPage: currentPage)
    }
    
    private func setupUI() {
        // Set background
        view.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        
        // Create container for all tutorial elements
        containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // Create icon image view
        iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .white
        containerView.addSubview(iconView)
        
        // Create title label
        titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        containerView.addSubview(titleLabel)
        
        // Create message label
        messageLabel = UILabel()
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = UIFont.systemFont(ofSize: 16)
        messageLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        containerView.addSubview(messageLabel)
        
        // Create page control
        pageControl = UIPageControl()
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.numberOfPages = pages.count
        pageControl.currentPage = 0
        pageControl.pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.3)
        pageControl.currentPageIndicatorTintColor = .white
        pageControl.addTarget(self, action: #selector(pageControlTapped(_:)), for: .valueChanged)
        containerView.addSubview(pageControl)
        
        // Create next button
        nextButton = UIButton(type: .system)
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.setTitle("Next", for: .normal)
        nextButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        nextButton.setTitleColor(.white, for: .normal)
        nextButton.backgroundColor = UIColor.blue
        nextButton.layer.cornerRadius = 22
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
        containerView.addSubview(nextButton)
        
        // Create skip button
        skipButton = UIButton(type: .system)
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.setTitle("Skip", for: .normal)
        skipButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        skipButton.setTitleColor(UIColor.white.withAlphaComponent(0.6), for: .normal)
        skipButton.addTarget(self, action: #selector(skipButtonTapped), for: .touchUpInside)
        containerView.addSubview(skipButton)
        
        // Tap gesture recognizer for tapping anywhere to continue
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(viewTapped))
        view.addGestureRecognizer(tapGesture)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Container view constraints - center in the screen
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.85),
            containerView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: 0.85),
            
            // Icon constraints
            iconView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            iconView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 80),
            iconView.heightAnchor.constraint(equalToConstant: 80),
            
            // Title constraints
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Message constraints
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            messageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Page control constraints
            pageControl.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 40),
            pageControl.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            // Next button constraints
            nextButton.topAnchor.constraint(equalTo: pageControl.bottomAnchor, constant: 40),
            nextButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 200),
            
            // Fix constraint conflicts by using a height priority instead of a fixed height
            // and removing one of the conflicting bottom constraints
            nextButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).withPriority(.defaultHigh),
        ])
        
        // Add separate constraints for the skip button with proper priorities
        // Instead of conflicting constraints, use a vertical spacing constraint
        if skipButton.isHidden {
            // If skip button is hidden, attach next button directly to container bottom
            NSLayoutConstraint.activate([
                nextButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
            ])
        } else {
            // If skip button is visible, use a vertical stack layout
            NSLayoutConstraint.activate([
                skipButton.topAnchor.constraint(equalTo: nextButton.bottomAnchor, constant: 16),
                skipButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                skipButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).withPriority(.defaultHigh),
                skipButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
            ])
        }
    }
    
    // Helper extension to add priority to constraints
    private func updateConstraints() {
        // Remove any existing constraints between buttons and container
        containerView.constraints.forEach { constraint in
            if (constraint.firstItem === nextButton && constraint.secondItem === containerView) ||
               (constraint.firstItem === skipButton && constraint.secondItem === containerView) ||
               (constraint.firstItem === containerView && constraint.secondItem === nextButton) ||
               (constraint.firstItem === containerView && constraint.secondItem === skipButton) {
                containerView.removeConstraint(constraint)
            }
        }
        
        // Re-apply appropriate constraints based on current state
        setupConstraints()
    }
    
    private func updateContent(forPage page: Int) {
        guard page >= 0 && page < pages.count else { return }
        
        UIView.animate(withDuration: 0.3) {
            self.iconView.image = UIImage(systemName: self.pages[page].image)?.withRenderingMode(.alwaysTemplate)
            self.titleLabel.text = self.pages[page].title
            self.messageLabel.text = self.pages[page].message
            self.pageControl.currentPage = page
            
            // Update next button title for the last page
            let isLastPage = page == self.pages.count - 1
            self.nextButton.setTitle(isLastPage ? "Get Started" : "Next", for: .normal)
            
            // Hide skip button on last page
            self.skipButton.isHidden = isLastPage
            
            // Update constraints whenever visibility changes
            self.updateConstraints()
        }
    }
    
    @objc private func nextButtonTapped() {
        if currentPage < pages.count - 1 {
            currentPage += 1
            updateContent(forPage: currentPage)
        } else {
            // On last page, dismiss tutorial
            dismiss(animated: true) {
                self.dismissCallback?()
            }
        }
    }
    
    @objc private func skipButtonTapped() {
        dismiss(animated: true) {
            self.dismissCallback?()
        }
    }
    
    @objc private func pageControlTapped(_ sender: UIPageControl) {
        currentPage = sender.currentPage
        updateContent(forPage: currentPage)
    }
    
    @objc private func viewTapped() {
        nextButtonTapped()
    }
} 