import SwiftUI
import AVFoundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct SplashView: View {
    let onFinished: () -> Void

    @StateObject private var splashVideoPlayer = SplashVideoPlayer()
    @State private var isReadyToNavigate = false
    @State private var navigationTask: Task<Void, Never>?

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

            navigationTask?.cancel()
            navigationTask = Task { @MainActor in
                let fallbackDuration: TimeInterval = 1.8

                if splashVideoPlayer.isConfigured {
                    splashVideoPlayer.playFromStart()
                    let duration = await splashVideoPlayer.loadPlaybackDuration()
                    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                } else {
                    try? await Task.sleep(nanoseconds: UInt64(fallbackDuration * 1_000_000_000))
                }

                guard !Task.isCancelled else { return }
                onFinished()
            }
        }
        .onDisappear {
            navigationTask?.cancel()
            navigationTask = nil
            splashVideoPlayer.pause()
        }
    }
}

@MainActor
private final class SplashVideoPlayer: ObservableObject {
    let player = AVPlayer()
    let isConfigured: Bool
    private let fallbackDuration: TimeInterval = 1.8

    init() {
        guard let videoURL = Bundle.main.url(forResource: "sc 9-16", withExtension: "mp4") else {
            isConfigured = false
            return
        }

        let item = AVPlayerItem(url: videoURL)
        player.replaceCurrentItem(with: item)
        player.isMuted = true
        player.actionAtItemEnd = .pause

        isConfigured = true
    }

    func loadPlaybackDuration() async -> TimeInterval {
        guard isConfigured, let asset = player.currentItem?.asset else {
            return fallbackDuration
        }

        do {
            let duration = try await asset.load(.duration)
            let seconds = duration.seconds
            return seconds.isFinite && seconds > 0 ? seconds : fallbackDuration
        } catch {
            return fallbackDuration
        }
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

#if canImport(UIKit)
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
#elseif canImport(AppKit)
private struct SplashVideoPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> SplashPlayerNSView {
        let view = SplashPlayerNSView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        return view
    }

    func updateNSView(_ nsView: SplashPlayerNSView, context: Context) {
        nsView.playerLayer.player = player
    }
}

private final class SplashPlayerNSView: NSView {
    override func makeBackingLayer() -> CALayer {
        AVPlayerLayer()
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
    }
}
#endif
