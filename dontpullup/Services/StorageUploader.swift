import Foundation
import FirebaseStorage
import UIKit
import FirebaseAuth

/// Utility class for handling Firebase Storage uploads
enum StorageUploader {
    
    /// Uploads a video to Firebase Storage if a local URL is provided
    /// - Parameters:
    ///   - pinId: The ID of the pin associated with this video
    ///   - localURL: Optional local URL of the video to upload
    /// - Returns: Remote URL as String (empty if no local URL was provided)
    /// - Throws: Error if upload fails
    static func uploadIfNeeded(pinId: String, localURL: URL?) async throws -> String {
        // If no local URL provided, return empty string (no video)
        guard let videoURL = localURL else {
            return ""
        }
        
        // Reference to Firebase Storage
        let storageRef = Storage.storage().reference().child("videos/\(pinId).mp4")
        
        // Create metadata with required fields from Storage rules
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        
        // Add userId to metadata as required by Storage rules
        if let currentUserId = Auth.auth().currentUser?.uid {
            metadata.customMetadata = [
                "userId": currentUserId,
                "timestamp": String(Date().timeIntervalSince1970)
            ]
        }
        
        // Upload the file
        let uploadTask = storageRef.putFile(from: videoURL, metadata: metadata)
        
        // Await upload completion using a continuation
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // Success handler
            let successHandle = uploadTask.observe(.success) { _ in
                continuation.resume()
            }
            
            // Failure handler
            let failureHandle = uploadTask.observe(.failure) { snapshot in
                let error = snapshot.error ?? NSError(
                    domain: "StorageUploader",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Unknown upload error"]
                )
                continuation.resume(throwing: error)
            }
            
            // Clean up observers to avoid memory leaks
            uploadTask.removeObserver(withHandle: successHandle)
            uploadTask.removeObserver(withHandle: failureHandle)
        }
        
        // Get download URL
        return try await storageRef.downloadURL().absoluteString
    }
} 