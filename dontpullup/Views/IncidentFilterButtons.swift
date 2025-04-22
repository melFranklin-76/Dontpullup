import SwiftUI

struct IncidentFilterButtons: View {
    @ObservedObject var viewModel: MapViewModel
    
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

private struct FilterButton: View {
    let type: IncidentType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(type.emoji)
                .font(.system(size: 24))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(RectangleButtonStyle(isSelected: isSelected))
    }
}
