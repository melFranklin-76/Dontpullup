import Network
import SwiftUI

/**
 The NetworkMonitor class is responsible for monitoring the network connectivity status.
 It uses NWPathMonitor to observe changes in the network path and updates the isConnected property accordingly.
 */
class NetworkMonitor: ObservableObject {
    @Published private(set) var isConnected = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        setupMonitoring()
    }
    
    /**
     Sets up the network monitoring by starting the NWPathMonitor and updating the isConnected property based on the network status.
     */
    private func setupMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
    
    /**
     Cancels the network monitoring when the NetworkMonitor instance is deallocated.
     */
    deinit {
        monitor.cancel()
    }
}
