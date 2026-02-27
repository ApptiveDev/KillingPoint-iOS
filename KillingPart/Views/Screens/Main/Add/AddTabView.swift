import SwiftUI

struct AddTabView: View {
    @StateObject private var viewModel = AddTabViewModel()
    @State private var dismissKeyboardSignal = 0

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Image("add_background")
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .ignoresSafeArea()

                    VStack(alignment: .leading, spacing: AppSpacing.m) {
                        AddSearchFieldView(
                            query: $viewModel.query,
                            hasQuery: viewModel.hasQuery,
                            dismissKeyboardSignal: dismissKeyboardSignal,
                            onSubmit: viewModel.submitSearch,
                            onQueryChanged: viewModel.handleQueryChanged,
                            onClear: viewModel.clearSearch
                        )

                        AddSearchContentView(
                            isLoading: viewModel.isLoading,
                            isLoadingMore: viewModel.isLoadingMore,
                            errorMessage: viewModel.errorMessage,
                            shouldShowEmptyState: viewModel.shouldShowEmptyState,
                            tracks: viewModel.tracks,
                            onRetry: viewModel.retrySearch,
                            onTrackAppear: viewModel.loadMoreIfNeeded,
                            onDiarySaved: viewModel.clearSearch
                        )
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            TapGesture()
                                .onEnded {
                                    dismissKeyboardSignal += 1
                                }
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.bottom, AppSpacing.l)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar(.hidden, for: .navigationBar)
            }
        }
    }
}
