import SwiftUI

struct AddSearchDetailVideoSection: View {
    @ObservedObject var viewModel: AddSearchDetailViewModel
    private let videoAspectRatio: CGFloat = 16 / 9
    private let videoCornerRadius: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {

            Group {
                if viewModel.isLoading {
                    loadingView
                } else if let video = viewModel.selectedVideo {
                    VStack(alignment: .leading, spacing: AppSpacing.s) {
                        YoutubePlayerView(
                            videoURL: video.embedURL,
                            startSeconds: viewModel.startSeconds,
                            endSeconds: viewModel.endSeconds
                        )
                            .frame(maxWidth: .infinity)
                            .aspectRatio(videoAspectRatio, contentMode: .fit)
                            .allowsHitTesting(false)
                            .clipShape(RoundedRectangle(cornerRadius: videoCornerRadius))
                            .overlay {
                                RoundedRectangle(cornerRadius: videoCornerRadius)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            }
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    errorView(message: errorMessage)
                } else {
                    emptyView
                }
            }
        }
        .padding(.horizontal, AppSpacing.xl)
    }

    private var loadingView: some View {
        VStack(spacing: AppSpacing.s) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(AppColors.primary600)

            Text("로딩 중...")
                .font(AppFont.paperlogy4Regular(size: 13))
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(videoAspectRatio, contentMode: .fit)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: videoCornerRadius))
    }

    private func errorView(message: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(message)
                .font(AppFont.paperlogy4Regular(size: 13))
                .foregroundStyle(.white.opacity(0.85))

            Button {
                Task {
                    await viewModel.retry()
                }
            } label: {
                Text("다시 검색")
                    .font(AppFont.paperlogy6SemiBold(size: 13))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppColors.primary600)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .aspectRatio(videoAspectRatio, contentMode: .fit)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: videoCornerRadius))
    }

    private var emptyView: some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(AppColors.primary600)

            Text("검색된 유튜브 영상이 없어요.")
                .font(AppFont.paperlogy4Regular(size: 13))
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(videoAspectRatio, contentMode: .fit)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: videoCornerRadius))
    }
}
