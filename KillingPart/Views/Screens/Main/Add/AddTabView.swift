import SwiftUI

struct AddTabView: View {
    @StateObject private var viewModel = AddTabViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    AddSearchFieldView(
                        query: $viewModel.query,
                        hasQuery: viewModel.hasQuery,
                        onSubmit: viewModel.submitSearch,
                        onQueryChanged: viewModel.handleQueryChanged,
                        onClear: viewModel.clearSearch
                    )

                    AddSearchContentView(
                        isLoading: viewModel.isLoading,
                        errorMessage: viewModel.errorMessage,
                        shouldShowEmptyState: viewModel.shouldShowEmptyState,
                        tracks: viewModel.tracks,
                        onRetry: viewModel.retrySearch
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 20)
                .padding(.horizontal, AppSpacing.l)
                .padding(.bottom, AppSpacing.l)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
