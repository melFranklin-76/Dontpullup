import Foundation
import FirebaseCore
import OSLog

/// LoggingManager provides utilities to control and filter Firebase logs
class LoggingManager {
    
    /// Singleton instance
    static let shared = LoggingManager()
    
    /// Log levels available for filtering
    enum LogLevel: String, CaseIterable {
        case verbose
        case debug
        case info
        case warning
        case error
        case none
    }
    
    /// Specific Firebase services that can be filtered
    enum LogService: String, CaseIterable {
        case analytics
        case auth
        case firestore
        case database
        case storage
        case functions
        case installations
        case all
    }
    
    /// Log entry structure for capturing app activity
    struct LogEntry {
        let timestamp: Date
        let level: LogLevel
        let category: String
        let message: String
        let file: String
        let function: String
        let line: Int
        
        var formattedMessage: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .medium
            return "[\(formatter.string(from: timestamp))] [\(level.rawValue.uppercased())] [\(category)] \(message)"
        }
    }
    
    // Current log level, defaults to info
    private var currentLogLevel: LogLevel = .info
    
    // Services to log, defaults to all
    private var enabledServices: Set<LogService> = [.all]
    
    // In-memory log storage (keep last 1000 entries)
    private var logEntries: [LogEntry] = []
    private let maxLogEntries = 1000
    private let queue = DispatchQueue(label: "logging.queue", qos: .background)
    
    // Private initializer for singleton
    private init() {
        // Add startup log
        log("LoggingManager initialized", level: .info, category: "System")
    }
    
    /// Log a message with specified level and category
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The log level
    ///   - category: The category/source of the log
    ///   - file: Source file (automatically filled)
    ///   - function: Source function (automatically filled)
    ///   - line: Source line (automatically filled)
    func log(_ message: String, 
             level: LogLevel = .info, 
             category: String = "App",
             file: String = #file,
             function: String = #function,
             line: Int = #line) {
        
        // Check if we should log this level
        guard shouldLog(level: level) else { return }
        
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            file: URL(fileURLWithPath: file).lastPathComponent,
            function: function,
            line: line
        )
        
        queue.async { [weak self] in
            self?.addLogEntry(entry)
        }
        
        // Also print to console in debug mode
        #if DEBUG
        print(entry.formattedMessage)
        #endif
    }
    
    /// Get recent log entries
    /// - Parameter count: Maximum number of entries to return (default: 100)
    /// - Returns: Array of recent log entries
    func getRecentLogs(count: Int = 100) -> [LogEntry] {
        return queue.sync {
            return Array(logEntries.suffix(count))
        }
    }
    
    /// Clear all stored log entries
    func clearLogs() {
        queue.async { [weak self] in
            self?.logEntries.removeAll()
        }
        log("Log entries cleared", level: .info, category: "System")
    }
    
    /// Set the minimum log level to display
    /// - Parameter level: The minimum log level
    func setLogLevel(_ level: LogLevel) {
        currentLogLevel = level
        applyLoggingSettings()
        log("Log level changed to \(level.rawValue)", level: .info, category: "System")
    }
    
    /// Enable logging for specific Firebase services
    /// - Parameter services: Array of services to enable logging for
    func enableLogging(for services: [LogService]) {
        enabledServices = Set(services)
        applyLoggingSettings()
        log("Enabled logging for services: \(services.map { $0.rawValue }.joined(separator: ", "))", level: .info, category: "System")
    }
    
    /// Disable all Firebase logs
    func disableAllLogs() {
        currentLogLevel = .none
        applyLoggingSettings()
        log("All logging disabled", level: .info, category: "System")
    }
    
    /// Enable all Firebase logs with verbose output
    func enableVerboseLogging() {
        currentLogLevel = .verbose
        enabledServices = [.all]
        applyLoggingSettings()
        log("Verbose logging enabled for all services", level: .info, category: "System")
    }
    
    /// Save current logs to a file for analysis
    /// - Returns: URL to the saved log file or nil if failed
    func saveLogs() -> URL? {
        let logs = collectCurrentLogs()
        
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fileURL = documentsDirectory.appendingPathComponent("dontpullup_logs_\(timestamp).txt")
        
        do {
            try logs.write(to: fileURL, atomically: true, encoding: .utf8)
            log("Logs saved to \(fileURL.path)", level: .info, category: "System")
            return fileURL
        } catch {
            log("Failed to save logs: \(error.localizedDescription)", level: .error, category: "System")
            return nil
        }
    }
    
    /// Get logs summary for last session
    /// - Returns: Summary of recent activity
    func getSessionSummary() -> String {
        let recentLogs = getRecentLogs(count: 50)
        let errorCount = recentLogs.filter { $0.level == .error }.count
        let warningCount = recentLogs.filter { $0.level == .warning }.count
        let categories = Set(recentLogs.map { $0.category })
        
        return """
        Session Summary (Last 50 entries):
        - Total logs: \(recentLogs.count)
        - Errors: \(errorCount)
        - Warnings: \(warningCount)
        - Active categories: \(categories.joined(separator: ", "))
        - Current log level: \(currentLogLevel.rawValue)
        """
    }
    
    // MARK: - Private methods
    
    private func shouldLog(level: LogLevel) -> Bool {
        guard currentLogLevel != .none else { return false }
        
        let levels: [LogLevel] = [.verbose, .debug, .info, .warning, .error]
        guard let currentIndex = levels.firstIndex(of: currentLogLevel),
              let messageIndex = levels.firstIndex(of: level) else {
            return false
        }
        
        return messageIndex >= currentIndex
    }
    
    private func addLogEntry(_ entry: LogEntry) {
        logEntries.append(entry)
        
        // Trim to max entries
        if logEntries.count > maxLogEntries {
            logEntries.removeFirst(logEntries.count - maxLogEntries)
        }
    }
    
    private func applyLoggingSettings() {
        // Apply log settings to Firebase
        var debugEnabled = false
        
        switch currentLogLevel {
        case .verbose, .debug:
            debugEnabled = true
        default:
            debugEnabled = false
        }
        
        // Set analytics debug mode if needed
        if enabledServices.contains(.analytics) || enabledServices.contains(.all) {
            FirebaseConfiguration.shared.setLoggerLevel(debugEnabled ? .debug : .error)
        }
        
        // Add other service-specific debug settings as needed
    }
    
    private func collectCurrentLogs() -> String {
        let entries = getRecentLogs(count: 500)
        
        var logContent = """
        Dontpullup App Logs - \(Date())
        Log level: \(currentLogLevel.rawValue)
        Enabled services: \(enabledServices.map { $0.rawValue }.joined(separator: ", "))
        Total entries: \(entries.count)
        
        """
        
        // Add session summary
        logContent += getSessionSummary()
        logContent += "\n\n=== LOG ENTRIES ===\n\n"
        
        // Add individual log entries
        for entry in entries {
            logContent += "\(entry.formattedMessage)\n"
            if entry.level == .error || entry.level == .warning {
                logContent += "    File: \(entry.file):\(entry.line) in \(entry.function)\n"
            }
        }
        
        return logContent
    }
}
