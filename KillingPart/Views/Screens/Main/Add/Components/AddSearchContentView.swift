import SwiftUI

struct AddSearchContentView: View {
    let isLoading: Bool
    let isLoadingMore: Bool
    let errorMessage: String?
    let shouldShowEmptyState: Bool
    let tracks: [SpotifySimpleTrack]
    let onRetry: () -> Void
    let onTrackAppear: (SpotifySimpleTrack.ID) -> Void
    let onDiarySaved: () -> Void

    var body: some View {
        Group {
            if isLoading {
                AddSearchLoadingView()
            } else if let errorMessage {
                AddSearchErrorView(message: errorMessage, onRetry: onRetry)
            } else if shouldShowEmptyState {
                AddSearchEmptyResultView()
            } else {
                AddTrackListView(
                    tracks: tracks,
                    isLoadingMore: isLoadingMore,
                    onTrackAppear: onTrackAppear,
                    onDiarySaved: onDiarySaved
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct AddSearchLoadingView: View {
    var body: some View {
        VStack(spacing: AppSpacing.s) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(AppColors.primary600)

            Text("검색 중...")
                .font(AppFont.paperlogy5Medium(size: 14))
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AddSearchErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(message)
                .font(AppFont.paperlogy4Regular(size: 14))
                .foregroundStyle(.white.opacity(0.85))

            Button {
                onRetry()
            } label: {
                Text("다시 시도")
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
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct AddSearchEmptyResultView: View {
    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: "music.note.list")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(AppColors.primary600.opacity(0.9))

            Text("검색 결과가 없어요.")
                .font(AppFont.paperlogy5Medium(size: 15))
                .foregroundStyle(.white.opacity(0.86))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
