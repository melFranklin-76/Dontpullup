import Foundation
import MetalKit

/// Utility class to help manage Metal resources and prevent texture deallocation issues
final class MetalResourceManager {
    // Singleton instance
    static let shared = MetalResourceManager()
    
    // Strong references to textures that are in use
    private var activeTextures = [String: MTLTexture]()
    private let lockQueue = DispatchQueue(label: "com.dontpullup.metalresourcemanager", attributes: .concurrent)
    
    private init() {}
    
    /// Register a texture to prevent premature deallocation
    /// - Parameters:
    ///   - texture: The texture to register
    ///   - identifier: A unique identifier for the texture
    func registerTexture(_ texture: MTLTexture, identifier: String) {
        lockQueue.async(flags: .barrier) { [weak self] in
            self?.activeTextures[identifier] = texture
        }
    }
    
    /// Unregister a texture when it's no longer needed
    /// - Parameter identifier: The identifier of the texture to unregister
    func unregisterTexture(identifier: String) {
        lockQueue.async(flags: .barrier) { [weak self] in
            self?.activeTextures.removeValue(forKey: identifier)
        }
    }
    
    /// Clear all registered textures
    func clearAll() {
        lockQueue.async(flags: .barrier) { [weak self] in
            self?.activeTextures.removeAll()
        }
    }
}

extension CAMetalLayer {
    /// Create a drawable with proper resource management
    /// - Returns: A metal drawable object with extended lifetime
    func safeNextDrawable() -> CAMetalDrawable? {
        guard let drawable = self.nextDrawable() else { return nil }
        
        // Register texture to prevent premature deallocation
        let identifier = "drawable_\(drawable.texture.hash)"
        MetalResourceManager.shared.registerTexture(drawable.texture, identifier: identifier)
        
        // Schedule unregistration after a delay to ensure command buffer completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            MetalResourceManager.shared.unregisterTexture(identifier: identifier)
        }
        
        return drawable
    }
}

// MARK: - Auto Release Pool Management
extension NSObject {
    /// Execute code within a fresh autorelease pool
    /// - Parameter block: The code to execute
    static func withAutoreleasePool(_ block: () -> Void) {
        autoreleasepool {
            block()
        }
    }
}

// MARK: - Command Buffer Extensions
extension MTLCommandBuffer {
    /// Commit with proper synchronization
    /// - Parameter textures: Textures to keep alive until completion
    func safeCommit(keepingAlive textures: [MTLTexture] = []) {
        // Store texture references in the manager
        for (index, texture) in textures.enumerated() {
            let identifier = "commandbuffer_\(self.hash)_texture_\(index)"
            MetalResourceManager.shared.registerTexture(texture, identifier: identifier)
        }
        
        // Register a completion handler to unregister when done
        self.addCompletedHandler { _ in
            for (index, _) in textures.enumerated() {
                let identifier = "commandbuffer_\(self.hash)_texture_\(index)"
                MetalResourceManager.shared.unregisterTexture(identifier: identifier)
            }
        }
        
        // Commit the command buffer
        self.commit()
    }
} 