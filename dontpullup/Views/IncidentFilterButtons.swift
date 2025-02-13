import SwiftUI

/// A view that displays buttons for filtering incidents by type.
struct IncidentFilterButtons: View {
    /// The view model that manages the state and behavior of the map view.
    @ObservedObject var viewModel: MapViewModel
    
    /// The body of the view, which contains the filter buttons.
    var body: some View {
        VStack(spacing: 8) {
            FilterButton(type: .verbal, isSelected: viewModel.selectedFilters.contains(.verbal)) {
                viewModel.toggleFilter(.verbal)
            }
            
            FilterButton(type: .physical, isSelected: viewModel.selectedFilters.contains(.physical)) {
                viewModel.toggleFilter(.physical)
            }
            
            FilterButton(type: .emergency, isSelected: viewModel.selectedFilters.contains(.emergency)) {
                viewModel.toggleFilter(.emergency)
            }
        }
        .padding(.vertical, 8)
    }
}

/// A private view that represents a filter button for a specific incident type.
private struct FilterButton: View {
    /// The type of incident that the button filters.
    let type: IncidentType
    /// A boolean indicating whether the button is selected.
    let isSelected: Bool
    /// The action to perform when the button is tapped.
    let action: () -> Void
    
    /// The body of the filter button view.
    var body: some View {
        Button(action: action) {
            Text(type.emoji)
                .font(.system(size: 24))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(RectangleButtonStyle(isSelected: isSelected))
    }
} 
