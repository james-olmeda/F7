import SwiftUI
import AVKit

/// Full-screen video player with FairPlay DRM, PIP support, and telemetry overlay.
public struct VideoPlayerView: View {
    @Environment(VideoPlayerViewModel.self) private var playerVM
    @Environment(TelemetryViewModel.self) private var telemetryVM
    
    let contentItem: F1TVContentItem
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = playerVM.player {
                // AVKit VideoPlayer with overlay
                VideoPlayer(player: player) {
                    // Telemetry overlay at bottom
                    VStack {
                        Spacer()
                        
                        // Track status banner
                        if telemetryVM.currentTrackStatus != .allClear &&
                           telemetryVM.currentTrackStatus != .unknown {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(telemetryVM.currentTrackStatus.description.uppercased())
                                    .font(.system(.caption, design: .default, weight: .black))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(trackStatusColor)
                            .cornerRadius(8)
                        }
                        
                        // ML Prediction overlay
                        PredictionOverlayView(
                            prediction: PredictionResult(
                                driverNumber: 1,
                                winProbability: 0.82,
                                predictedNextLapTime: 92.4
                            )
                        )
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }
                .ignoresSafeArea()

            } else if playerVM.isLoading {
                // Show thumbnail preview while stream loads
                if let pictureUrl = contentItem.pictureUrl {
                    GeometryReader { geo in
                        F1TVImageView(pictureUrl: pictureUrl, width: geo.size.width, height: geo.size.height)
                    }
                    .ignoresSafeArea()
                    .overlay {
                        Color.black.opacity(0.4)
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("Loading stream...")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            Text(contentItem.title)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.red)
                        Text("Loading stream...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(contentItem.title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
            } else if let error = playerVM.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Playback Error")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Retry") {
                        Task { await playerVM.loadContent(contentItem) }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .padding()
            }
        }
        .navigationTitle(contentItem.title)
        .navigationBarTitleDisplayMode(.inline)
        .persistentSystemOverlays(.hidden)
        .task {
            await playerVM.loadContent(contentItem)
        }
        .onDisappear {
            playerVM.cleanup()
        }
    }
    
    private var trackStatusColor: Color {
        switch telemetryVM.currentTrackStatus {
        case .yellow, .virtualSafetyCar, .virtualSafetyCarEnding: return .yellow
        case .safetyCar: return .orange
        case .redFlag: return .red
        default: return .clear
        }
    }
}
