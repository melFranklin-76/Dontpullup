import SwiftUI

struct IncidentTypePicker: View {
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List(IncidentType.allCases, id: \.self) { type in
                Button {
                    viewModel.dropPin(for: type)
                } label: {
                    HStack {
                        Text(type.emoji)
                            .font(.title)
                        VStack(alignment: .leading) {
                            Text(type.title)
                                .font(.headline)
                            Text(type.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Select Incident Type")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.pendingCoordinate = nil
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: viewModel.showingIncidentPicker) { isShowing in
            if !isShowing {
                dismiss()
            }
        }
    }
} 
