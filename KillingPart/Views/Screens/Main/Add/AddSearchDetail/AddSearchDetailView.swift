import SwiftUI

struct AddSearchDetailView: View {
    @StateObject private var viewModel: AddSearchDetailViewModel

    init(track: SpotifySimpleTrack) {
        _viewModel = StateObject(wrappedValue: AddSearchDetailViewModel(track: track))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    AddSearchDetailVideoSection(viewModel: viewModel)
                    AddSearchDetailTrackInfoSection(track: viewModel.track)
                    AddSearchDetailTrimSection(viewModel: viewModel)

                    if viewModel.videos.count > 1 {
                        AddSearchDetailVideoCandidateSection(viewModel: viewModel)
                    }
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, AppSpacing.m)
                .padding(.bottom, AppSpacing.l)
            }
            .scrollIndicators(.hidden)
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .navigationTitle("음악 상세")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        AddSearchDetailView(track: SpotifySimpleTrack(
            id: "preview-track-id",
            title: "Ditto",
            artist: "NewJeans",
            albumImageUrl: nil,
            albumId: "preview-album-id"
        ))
    }
}
