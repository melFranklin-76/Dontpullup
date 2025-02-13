import SwiftUI
import MapKit

struct MapStyleModifier: ViewModifier {
    private var cache = NSCache<NSString, MKTileOverlay>()
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                applyMapStyle()
            }
    }
    
    private func applyMapStyle() {
        guard let mapView = findMapView() else { return }
        
        // Check cache for existing style
        if let cachedOverlay = cache.object(forKey: "defaultStyle") {
            mapView.addOverlay(cachedOverlay)
            return
        }
        
        // Load and apply map style
        if let styleURL = Bundle.main.url(forResource: "default", withExtension: "json"),
           let styleData = try? Data(contentsOf: styleURL),
           let style = try? JSONSerialization.jsonObject(with: styleData, options: []) as? [String: Any] {
            
            let tileOverlay = MKTileOverlay()
            tileOverlay.canReplaceMapContent = true
            mapView.addOverlay(tileOverlay)
            
            // Cache the style
            cache.setObject(tileOverlay, forKey: "defaultStyle")
        }
    }
    
    private func findMapView() -> MKMapView? {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .map { $0 as? UIWindowScene }
            .compactMap { $0 }
            .first?.windows
            .filter { $0.isKeyWindow }
            .first
        
        return keyWindow?.rootViewController?.view.subviews.compactMap { $0 as? MKMapView }.first
    }
}

extension View {
    func withMapStyle() -> some View {
        self.modifier(MapStyleModifier())
    }
}
