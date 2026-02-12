import SwiftUI
import AVFoundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct LoginView: View {
    @ObservedObject var viewModel: LoginViewModel

    var body: some View {
        GeometryReader { geometry in
            let logoWidth = min(max(geometry.size.width * 0.82, 220), 560)
            let horizontalPadding = max(AppSpacing.m, geometry.size.width * 0.06)
            let topPadding = geometry.safeAreaInsets.top + AppSpacing.l
            let bottomPadding = geometry.safeAreaInsets.bottom + AppSpacing.l

            ZStack {
                LoginBackgroundVideoView()
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [Color.black.opacity(0.15), Color.black.opacity(0.72)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Image("loginTitle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: logoWidth)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .padding(.top, topPadding)
                        .padding(.horizontal, horizontalPadding)

                    Spacer(minLength: AppSpacing.l)

                    VStack(spacing: AppSpacing.m) {
                        Text("SNS로 간편로그인")
                            .font(AppFont.paperlogy5Medium(size: 15))
                            .foregroundStyle(.white.opacity(0.92))

                        if let message = viewModel.loginErrorMessage {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(Color.red.opacity(0.95))
                        }

                        KakaoLoginButton(
                            isLoading: viewModel.isLoading,
                            action: viewModel.loginWithKakao
                        )
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, bottomPadding)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }
}

#Preview {
    LoginView(viewModel: LoginViewModel())
}

private struct KakaoLoginButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                HStack(spacing: 4) {
                    Image("kakaoTalkBubble")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 19, height: 19)
                        .foregroundStyle(Color.black)

                    Text("카카오 로그인")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.85))
                        .lineLimit(1)
                }
                .padding(.horizontal, 20)

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(Color.black.opacity(0.85))
                            .padding(.trailing, 20)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .background(Color(hex: "#FEE500"))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

private struct LoginBackgroundVideoView: View {
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
