import AVKit
import SwiftUI

/**
 The PresentationCoordinator class is responsible for presenting videos using AVPlayerViewController.
 */
class PresentationCoordinator: NSObject, AVPlayerViewControllerDelegate {
    private var cache = NSCache<NSString, NSURL>()
    
    /**
     Presents a video from the given URL in the specified view controller.
     
     - Parameters:
        - url: The URL of the video to be presented.
        - viewController: The view controller in which the video will be presented.
     */
    func presentVideo(from url: URL, in viewController: UIViewController) {
        let cacheKey = url.absoluteString as NSString
        
        if let cachedURL = cache.object(forKey: cacheKey) {
            print("Loaded video URL from cache")
            playVideo(from: cachedURL as URL, in: viewController)
        } else {
            cache.setObject(url as NSURL, forKey: cacheKey)
            print("Video URL loaded and cached")
            playVideo(from: url, in: viewController)
        }
    }
    
    /**
     Plays a video from the given URL in the specified view controller.
     
     - Parameters:
        - url: The URL of the video to be played.
        - viewController: The view controller in which the video will be played.
     */
    private func playVideo(from url: URL, in viewController: UIViewController) {
        let player = AVPlayer(url: url)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        playerViewController.delegate = self
        viewController.present(playerViewController, animated: true) {
            player.play()
        }
    }
}
