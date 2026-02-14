import SwiftUI
import AVFoundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct LoginBackgroundVideoView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var videoPlayer = LoginBackgroundVideoPlayer()

    var body: some View {
        Group {
            if videoPlayer.isConfigured {
                LoginVideoPlayerView(player: videoPlayer.player)
            } else {
                Color.black
            }
        }
        .onAppear {
            videoPlayer.play()
        }
        .onDisappear {
            videoPlayer.pause()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                videoPlayer.play()
            }
        }
#if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            videoPlayer.play()
        }
#endif
    }
}

@MainActor
private final class LoginBackgroundVideoPlayer: ObservableObject {
    let player = AVPlayer()
    let isConfigured: Bool

    private var endObserver: NSObjectProtocol?

    init() {
        guard let videoURL = Bundle.main.url(forResource: "login", withExtension: "mp4") else {
            isConfigured = false
            return
        }

        let item = AVPlayerItem(url: videoURL)
        player.replaceCurrentItem(with: item)
        player.isMuted = true
        player.actionAtItemEnd = .none

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }

        isConfigured = true
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    func play() {
        guard isConfigured else { return }
        player.play()
    }

    func pause() {
        player.pause()
    }
}

#if canImport(UIKit)
private struct LoginVideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> LoginPlayerUIView {
        let view = LoginPlayerUIView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: LoginPlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class LoginPlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}
#elseif canImport(AppKit)
private struct LoginVideoPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> LoginPlayerNSView {
        let view = LoginPlayerNSView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        return view
    }

    func updateNSView(_ nsView: LoginPlayerNSView, context: Context) {
        nsView.playerLayer.player = player
    }
}

private final class LoginPlayerNSView: NSView {
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
