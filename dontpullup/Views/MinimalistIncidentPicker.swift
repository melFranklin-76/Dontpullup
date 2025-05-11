import SwiftUI

/// Minimalist incident type picker shown immediately after long-press
struct MinimalistIncidentPicker: View {
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 25) {
            ForEach(IncidentType.allCases, id: \.self) { type in
                Button {
                    // User selected an incident type
                    viewModel.reportDraft.incidentType = type
                    
                    // Dismiss this picker
                    dismiss()
                    
                    // Post notification to present photo picker next
                    NotificationCenter.default.post(
                        name: .incidentTypeSelected,
                        object: nil,
                        userInfo: ["incidentType": type]
                    )
                } label: {
                    VStack(spacing: 4) {
                        Text(type.emoji)
                            .font(.system(size: 50))
                        
                        Text(type.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(width: 85, height: 85)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(type.color.opacity(0.2))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(type.color, lineWidth: 1)
                    )
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 15)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? 
                      Color.black.opacity(0.8) : 
                      Color.white.opacity(0.9))
                .shadow(color: Color.black.opacity(0.2), radius: 10)
        )
        // Force a small size presentation that fits just the buttons
        .presentationDetents([.height(140)])
        .presentationBackground(.ultraThinMaterial)
    }
}

// MARK: - Previews
struct MinimalistIncidentPicker_Previews: PreviewProvider {
    static var previews: some View {
        MinimalistIncidentPicker(viewModel: MapViewModel(authState: AuthState.shared))
            .environment(\.colorScheme, .dark)
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.gray)
        
        MinimalistIncidentPicker(viewModel: MapViewModel(authState: AuthState.shared))
            .environment(\.colorScheme, .light)
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.white)
    }
} 