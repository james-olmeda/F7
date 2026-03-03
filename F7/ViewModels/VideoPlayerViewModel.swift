import Foundation
import AVFoundation

/// Manages video playback state including AVPlayer setup, FairPlay DRM integration, and PIP.
@Observable
public final class VideoPlayerViewModel {
    
    /// The AVPlayer instance for video playback.
    public var player: AVPlayer?
    
    /// Whether the stream is currently loading.
    public var isLoading: Bool = false
    
    /// Error message if stream loading fails.
    public var errorMessage: String?
    
    /// The content item currently being played.
    public var currentContentItem: F1TVContentItem?
    
    /// Whether video is currently playing.
    public var isPlaying: Bool = false
    
    private let contentService: F1TVContentService
    
    public init(contentService: F1TVContentService) {
        self.contentService = contentService
        configureAudioSession()
    }
    
    // MARK: - Public API
    
    /// Loads and plays a content item: fetches entitlement, sets up DRM, creates AVPlayer.
    public func loadContent(_ item: F1TVContentItem) async {
        guard !isLoading else {
            print("[VideoPlayerViewModel] Already loading, ignoring duplicate request.")
            return
        }
        isLoading = true
        errorMessage = nil
        currentContentItem = item
        
        do {
            print("[VideoPlayerViewModel] Loading stream for: \(item.title)")
            
            let entitlement = try await contentService.fetchStreamEntitlement(contentId: item.id)
            
            // F1TV HLS streams are token-gated, not FairPlay-encrypted.
            // The entitlement token was only needed to obtain the stream URL.
            // AVPlayer can play the HLS manifest directly once we have it.
            let asset = AVURLAsset(url: entitlement.streamURL)
            let playerItem = AVPlayerItem(asset: asset)
            
            await MainActor.run {
                self.player = AVPlayer(playerItem: playerItem)
                self.player?.play()
                self.isPlaying = true
                self.isLoading = false
                print("[VideoPlayerViewModel] Playback started for: \(item.title)")
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load stream: \(error.localizedDescription)"
                self.isLoading = false
                print("[VideoPlayerViewModel] Stream load failed: \(error)")
            }
        }
    }
    
    /// Toggles play/pause state.
    public func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    /// Cleans up the player.
    public func cleanup() {
        player?.pause()
        player = nil
        isPlaying = false
        currentContentItem = nil
        print("[VideoPlayerViewModel] Player cleaned up.")
    }
    
    // MARK: - Private
    
    /// Configures the audio session for video playback and PIP support.
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
            print("[VideoPlayerViewModel] Audio session configured for playback.")
        } catch {
            print("[VideoPlayerViewModel] Failed to configure audio session: \(error)")
        }
    }
}
