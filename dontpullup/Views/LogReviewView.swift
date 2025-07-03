import SwiftUI
import UniformTypeIdentifiers

/// View for reviewing recent app logs and activity
struct LogReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var logEntries: [LoggingManager.LogEntry] = []
    @State private var selectedLogLevel: LoggingManager.LogLevel = .info
    @State private var searchText = ""
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    private let loggingManager = LoggingManager.shared
    
    var filteredLogs: [LoggingManager.LogEntry] {
        var filtered = logEntries
        
        // Filter by log level
        let levels: [LoggingManager.LogLevel] = [.verbose, .debug, .info, .warning, .error]
        if let selectedIndex = levels.firstIndex(of: selectedLogLevel) {
            filtered = filtered.filter { entry in
                if let entryIndex = levels.firstIndex(of: entry.level) {
                    return entryIndex >= selectedIndex
                }
                return false
            }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { entry in
                entry.message.localizedCaseInsensitiveContains(searchText) ||
                entry.category.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with summary
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Recent Activity")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(filteredLogs.count) entries")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Text(loggingManager.getSessionSummary())
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(3)
                }
                .padding()
                .background(Color.black.opacity(0.8))
                
                // Filters
                VStack(spacing: 12) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search logs...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(.white)
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    
                    // Log level picker
                    HStack {
                        Text("Level:")
                            .foregroundColor(.white)
                            .font(.caption)
                        
                        Picker("Log Level", selection: $selectedLogLevel) {
                            ForEach(LoggingManager.LogLevel.allCases.filter { $0 != .none }, id: \.self) { level in
                                Text(level.rawValue.capitalized)
                                    .tag(level)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Log entries list
                List {
                    ForEach(Array(filteredLogs.enumerated()), id: \.offset) { index, entry in
                        LogEntryRow(entry: entry)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(PlainListStyle())
                .background(Color.clear)
            }
            .background(Color.black)
            .navigationTitle("Log Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: exportLogs) {
                            Label("Export Logs", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: clearLogs) {
                            Label("Clear Logs", systemImage: "trash")
                        }
                        
                        Button(action: refreshLogs) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            refreshLogs()
        }
        .alert("Log Review", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareURL = shareURL {
                ActivityViewController(activityItems: [shareURL])
            }
        }
    }
    
    private func refreshLogs() {
        logEntries = loggingManager.getRecentLogs(count: 200)
        loggingManager.log("Log review accessed", level: .info, category: "UI")
    }
    
    private func clearLogs() {
        loggingManager.clearLogs()
        refreshLogs()
        alertMessage = "All logs have been cleared"
        showAlert = true
    }
    
    private func exportLogs() {
        guard let url = loggingManager.saveLogs() else {
            alertMessage = "Failed to export logs"
            showAlert = true
            return
        }
        
        shareURL = url
        showShareSheet = true
    }
}

/// Individual log entry row
struct LogEntryRow: View {
    let entry: LoggingManager.LogEntry
    
    private var levelColor: Color {
        switch entry.level {
        case .error:
            return .red
        case .warning:
            return .orange
        case .info:
            return .blue
        case .debug:
            return .green
        case .verbose:
            return .purple
        case .none:
            return .gray
        }
    }
    
    private var levelIcon: String {
        switch entry.level {
        case .error:
            return "xmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        case .debug:
            return "bug.fill"
        case .verbose:
            return "text.alignleft"
        case .none:
            return "circle"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Level indicator
                Image(systemName: levelIcon)
                    .foregroundColor(levelColor)
                    .font(.caption)
                
                // Category
                Text(entry.category)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(4)
                
                Spacer()
                
                // Timestamp
                Text(timeString(from: entry.timestamp))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Message
            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            
            // Additional info for errors/warnings
            if entry.level == .error || entry.level == .warning {
                Text("\(entry.file):\(entry.line)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

/// Activity view controller for sharing logs
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    LogReviewView()
}