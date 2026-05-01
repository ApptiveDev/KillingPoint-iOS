import SwiftUI

struct TutorialTrackSearchScreen: View {
    @StateObject private var searchViewModel = AddTabViewModel()
    @State private var dismissKeyboardSignal = 0

    let onSkip: () -> Void
    let onTrackSelected: (SpotifySimpleTrack) -> Void

    var body: some View {
        GeometryReader { geometry in
            let listBottomInset = max(geometry.safeAreaInsets.bottom, AppSpacing.m) + AppSpacing.xl

            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [Color.black, Color(hex: "#1A1D27")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: AppSpacing.m) {
                    VStack(spacing: 4) {
                        Text("어떤 곡으로 시작할까요?")
                            .font(AppFont.paperlogy8ExtraBold(size: 30))
                            .foregroundStyle(.white)
                        Text("킬링파트 제작하기")
                            .font(AppFont.paperlogy4Regular(size: 15))
                            .foregroundStyle(.white.opacity(0.68))
                    }
                    .padding(.bottom, AppSpacing.s)

                    AddSearchFieldView(
                        query: $searchViewModel.query,
                        hasQuery: searchViewModel.hasQuery,
                        dismissKeyboardSignal: dismissKeyboardSignal,
                        onSubmit: searchViewModel.submitSearch,
                        onQueryChanged: searchViewModel.handleQueryChanged,
                        onClear: searchViewModel.clearSearch
                    )

                    tutorialTrackContent(bottomInset: listBottomInset)
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            TapGesture()
                                .onEnded { dismissKeyboardSignal += 1 }
                        )
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, AppSpacing.l)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            InitialSetupSkipButtonRow(onSkip: onSkip)
        }
    }

    @ViewBuilder
    private func tutorialTrackContent(bottomInset: CGFloat) -> some View {
        if searchViewModel.isLoading {
            VStack {
                Spacer(minLength: 0)
                ProgressView()
                    .tint(AppColors.primary600)
                Spacer(minLength: 0)
            }
        } else if let error = searchViewModel.errorMessage {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text(error)
                    .font(AppFont.paperlogy4Regular(size: 14))
                    .foregroundStyle(.white.opacity(0.85))

                Button("다시 시도") {
                    searchViewModel.retrySearch()
                }
                .buttonStyle(.plain)
                .font(AppFont.paperlogy6SemiBold(size: 13))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(.black)
                .background(AppColors.primary600)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.m)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        } else if searchViewModel.shouldShowEmptyState {
            VStack {
                Spacer(minLength: 0)
                Text("검색 결과가 없어요.")
                    .font(AppFont.paperlogy5Medium(size: 15))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer(minLength: 0)
            }
        } else {
            ScrollView {
                LazyVStack(spacing: AppSpacing.s) {
                    ForEach(searchViewModel.tracks) { track in
                        Button {
                            onTrackSelected(track)
                        } label: {
                            TutorialTrackRow(track: track)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            searchViewModel.loadMoreIfNeeded(currentTrackID: track.id)
                        }
                    }

                    if searchViewModel.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(.white.opacity(0.85))
                            Spacer()
                        }
                        .padding(.top, AppSpacing.s)
                    }
                }
                .padding(.bottom, max(bottomInset, AppSpacing.l))
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct TutorialTrackRow: View {
    let track: SpotifySimpleTrack

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            Group {
                if let artworkURL = track.albumImageURL {
                    AsyncImage(url: artworkURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .empty, .failure:
                            placeholder
                        @unknown default:
                            placeholder
                        }
                    }
                } else {
                    placeholder
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(AppFont.paperlogy6SemiBold(size: 15))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(track.artist)
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.s)
        .background(Color.black.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .overlay {
                Image(systemName: "music.note")
                    .foregroundStyle(.white.opacity(0.72))
            }
    }
}
