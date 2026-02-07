import SwiftUI
import AVFoundation
import UIKit

struct SplashView: View {
    let onFinished: () -> Void

    @StateObject private var splashVideoPlayer = SplashVideoPlayer()
    @State private var isReadyToNavigate = false

    var body: some View {
        ZStack {
            if splashVideoPlayer.isConfigured {
                SplashVideoPlayerView(player: splashVideoPlayer.player)
                    .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [Color.black, AppColors.primary300.opacity(0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }

            LinearGradient(
                colors: [Color.black.opacity(0.08), Color.black.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .onAppear {
            guard !isReadyToNavigate else { return }
            isReadyToNavigate = true

            if splashVideoPlayer.isConfigured {
                splashVideoPlayer.playFromStart()
                DispatchQueue.main.asyncAfter(deadline: .now() + splashVideoPlayer.playbackDuration) {
                    onFinished()
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    onFinished()
                }
            }
        }
        .onDisappear {
            splashVideoPlayer.pause()
        }
    }
}

@MainActor
private final class SplashVideoPlayer: ObservableObject {
    let player = AVPlayer()
    let isConfigured: Bool
    let playbackDuration: TimeInterval

    init() {
        guard let videoURL = Bundle.main.url(forResource: "sc 9-16", withExtension: "mp4") else {
            isConfigured = false
            playbackDuration = 1.8
            return
        }

        let item = AVPlayerItem(url: videoURL)
        player.replaceCurrentItem(with: item)
        player.isMuted = true
        player.actionAtItemEnd = .pause

        isConfigured = true
        let duration = item.asset.duration.seconds
        playbackDuration = duration.isFinite && duration > 0 ? duration : 1.8
    }

    func playFromStart() {
        guard isConfigured else { return }
        player.seek(to: .zero)
        player.play()
    }

    func pause() {
        player.pause()
    }
}

private struct SplashVideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> SplashPlayerUIView {
        let view = SplashPlayerUIView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: SplashPlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class SplashPlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}
