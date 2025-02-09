import SwiftUI
import Network
import FirebaseFirestore

class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = true
    @Published var isFirestoreConnected = true
    
    init() {
        setupNetworkMonitoring()
        setupFirestoreMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
    
    private func setupFirestoreMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFirestoreConnection(_:)),
            name: Notification.Name("FirestoreConnectionStatus"),
            object: nil
        )
    }
    
    @objc private func handleFirestoreConnection(_ notification: Notification) {
        if let isConnected = notification.userInfo?["isConnected"] as? Bool {
            DispatchQueue.main.async {
                self.isFirestoreConnected = isConnected
            }
        }
    }
    
    deinit {
        monitor.cancel()
        NotificationCenter.default.removeObserver(self)
    }
} 