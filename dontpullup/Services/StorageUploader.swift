import Foundation
@preconcurrency import FirebaseStorage
import UIKit
import FirebaseAuth
// Import SwiftUI to access the extensions defined in MapViewModel
import SwiftUI
import AVFoundation

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
            print("[StorageUploader] No video URL provided, skipping upload")
            return ""
        }
        
        // Compress video if needed
        let uploadURL = await compressVideoIfNeeded(inputURL: videoURL)
        
        print("[StorageUploader] Starting video upload process for pin \(pinId)")
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: uploadURL.path) else {
            print("[StorageUploader] Error: File does not exist at \(uploadURL.path)")
            throw NSError(domain: "StorageUploader", code: 404, userInfo: [NSLocalizedDescriptionKey: "Video file not found"])
        }
        
        // Get file size for diagnostics
        let fileSize: Int64
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: uploadURL.path)
            fileSize = attributes[.size] as? Int64 ?? 0
            print("[StorageUploader] Video file size: \(Double(fileSize) / 1024.0 / 1024.0) MB")
        } catch {
            print("[StorageUploader] Could not determine file size: \(error.localizedDescription)")
            fileSize = 0
        }
        
        // Make sure the user is authenticated
        guard let user = Auth.auth().currentUser else {
            print("[StorageUploader] Error: No authenticated user")
            throw NSError(domain: "StorageUploader", code: 401, userInfo: [NSLocalizedDescriptionKey: "User must be logged in to upload videos"])
        }
        
        // Create storage reference
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let videosRef = storageRef.child("videos/\(user.uid)/\(pinId).mp4")
        
        // Upload the file
        return try await withCheckedThrowingContinuation { continuation in
            let uploadTask = videosRef.putFile(from: uploadURL, metadata: nil) { metadata, error in
                if let error = error {
                    print("[StorageUploader] Upload error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                // Success - now get the download URL
                videosRef.downloadURL { url, error in
                    if let error = error {
                        print("[StorageUploader] Failed to get download URL: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let downloadURL = url else {
                        print("[StorageUploader] Error: Download URL is nil")
                        continuation.resume(throwing: NSError(domain: "StorageUploader", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"]))
                        return
                    }
                    
                    print("[StorageUploader] Video upload complete. URL: \(downloadURL.absoluteString)")
                    continuation.resume(returning: downloadURL.absoluteString)
                }
            }
            
            // Create a holder for the upload task to avoid Sendable warnings
            // Using @unchecked Sendable for the class that wraps the task
            class TaskHolder: @unchecked Sendable {
                var task: StorageUploadTask?
                
                init(task: StorageUploadTask) {
                    self.task = task
                }
            }
            
            _ = TaskHolder(task: uploadTask)
            
            // Set up observers for progress and completion
            uploadTask.observe(.progress) { snapshot in
                guard let progress = snapshot.progress?.fractionCompleted else { return }
                
                // Post a notification with the progress for any observers
                NotificationCenter.default.post(
                    name: .videoUploadProgressUpdated,
                    object: nil,
                    userInfo: ["progress": progress]
                )
                
                // Also post directly to MainActor for immediate reflection in UI
                NotificationCenter.default.post(
                    name: .uploadProgressUpdatedMainActor,
                    object: nil,
                    userInfo: ["progress": progress]
                )
            }
        }
    }
    
    static func compressVideoIfNeeded(inputURL: URL) async -> URL {
        // If the file is already small (<20MB), skip compression
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: inputURL.path)[.size] as? Int64) ?? 0
        if fileSize > 0 && fileSize < 20 * 1024 * 1024 {
            return inputURL
        }
        // Prepare output URL
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("compressed_\(UUID().uuidString).mp4")
        // Set up export session
        let asset = AVAsset(url: inputURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else {
            print("[StorageUploader] Could not create export session, using original video")
            return inputURL
        }
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        // Run export
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            exportSession.exportAsynchronously {
                continuation.resume()
            }
        }
        // Check if export succeeded
        if exportSession.status == .completed, FileManager.default.fileExists(atPath: outputURL.path) {
            print("[StorageUploader] Video compressed to: \(outputURL.path)")
            return outputURL
        } else {
            print("[StorageUploader] Compression failed, using original video")
            return inputURL
        }
    }
}

// Extension is now imported from MapViewModel via SwiftUI 