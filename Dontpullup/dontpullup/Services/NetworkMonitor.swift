import Network
import SwiftUI

class NetworkMonitor: ObservableObject {
    @Published private(set) var isConnected = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        setupMonitoring()
        
        // Add observer for custom foreground notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppForeground),
            name: NSNotification.Name("AppWillEnterForeground"),
            object: nil
        )
    }
    
    private func setupMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
    
    @objc private func handleAppForeground() {
        // Force network status update when app returns to foreground
        DispatchQueue.main.async { [weak self] in
            // Restart monitoring to refresh status
            self?.monitor.cancel()
            self?.monitor.start(queue: self?.queue ?? DispatchQueue(label: "NetworkMonitor"))
            
            // Manually check status
            let currentStatus = self?.monitor.currentPath.status == .satisfied
            if self?.isConnected != currentStatus {
                self?.isConnected = currentStatus
            }
            
            print("NetworkMonitor: Updated connection status after returning to foreground - isConnected: \(currentStatus)")
        }
    }
    
    deinit {
        monitor.cancel()
        NotificationCenter.default.removeObserver(self)
    }
} 