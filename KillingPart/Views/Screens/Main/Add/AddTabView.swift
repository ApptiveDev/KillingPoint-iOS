import SwiftUI

struct AddTabView: View {
    @StateObject private var viewModel = AddTabViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(alignment: .leading, spacing: AppSpacing.m) {

                    searchField

                    searchContent
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 20)    
                .padding(.horizontal, AppSpacing.l)
                .padding(.bottom, AppSpacing.l)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var searchField: some View {
        HStack(spacing: AppSpacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.7))

            TextField("곡 또는 아티스트 검색", text: $viewModel.query)
                .font(AppFont.paperlogy5Medium(size: 15))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.search)
                .onSubmit {
                    viewModel.submitSearch()
                }
                .onChange(of: viewModel.query) { _ in
                    viewModel.handleQueryChanged()
                }

            if viewModel.hasQuery {
                Button {
                    viewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.75))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.primary600.opacity(0.45), lineWidth: 1)
        }
    }

    private var searchContent: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let errorMessage = viewModel.errorMessage {
                errorView(message: errorMessage)
            } else if viewModel.shouldShowEmptyState {
                emptyResultView
            } else {
                trackListView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var loadingView: some View {
        VStack(spacing: AppSpacing.s) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(AppColors.primary600)

            Text("Spotify 검색 중...")
                .font(AppFont.paperlogy5Medium(size: 14))
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(message)
                .font(AppFont.paperlogy4Regular(size: 14))
                .foregroundStyle(.white.opacity(0.85))

            Button {
                viewModel.retrySearch()
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

    private var emptyResultView: some View {
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

    private var trackListView: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.s) {
                ForEach(viewModel.tracks) { track in
                    trackRow(track)
                }
            }
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.l)
        }
        .scrollIndicators(.hidden)
    }

    private func trackRow(_ track: SpotifySimpleTrack) -> some View {
        HStack(spacing: AppSpacing.s) {
            trackArtwork(url: track.albumImageURL)

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
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func trackArtwork(url: URL?) -> some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty, .failure:
                        artworkPlaceholder
                    @unknown default:
                        artworkPlaceholder
                    }
                }
            } else {
                artworkPlaceholder
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var artworkPlaceholder: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .overlay {
                Image(systemName: "music.note")
                    .foregroundStyle(.white.opacity(0.72))
            }
    }
}
