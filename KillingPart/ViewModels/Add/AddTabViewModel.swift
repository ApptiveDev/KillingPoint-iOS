import Foundation

@MainActor
final class AddTabViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var tracks: [SpotifySimpleTrack] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published var errorMessage: String?

    private let spotifyService: SpotifyServicing
    private var searchTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?
    private var lastSearchedQuery = ""
    private let pageSize = 10
    private var nextOffset = 0
    private var hasMoreResults = true

    init(spotifyService: SpotifyServicing = SpotifyService()) {
        self.spotifyService = spotifyService
    }

    deinit {
        searchTask?.cancel()
        loadMoreTask?.cancel()
    }

    var hasQuery: Bool {
        !trimmedQuery.isEmpty
    }

    var shouldShowEmptyState: Bool {
        hasSearchedCurrentQuery && !isLoading && errorMessage == nil && tracks.isEmpty
    }

    func handleQueryChanged() {
        searchTask?.cancel()
        loadMoreTask?.cancel()
        isLoading = false
        isLoadingMore = false

        guard hasQuery else {
            lastSearchedQuery = ""
            tracks = []
            errorMessage = nil
            resetPagingState()
            return
        }

        if !hasSearchedCurrentQuery {
            tracks = []
            errorMessage = nil
            resetPagingState()
        }
    }

    func submitSearch() {
        searchTask?.cancel()
        loadMoreTask?.cancel()

        guard hasQuery else {
            tracks = []
            errorMessage = nil
            isLoading = false
            isLoadingMore = false
            resetPagingState()
            return
        }

        let currentQuery = trimmedQuery
        lastSearchedQuery = currentQuery
        resetPagingState()
        searchTask = Task { [weak self] in
            await self?.search(query: currentQuery, offset: 0, mode: .initial)
        }
    }

    func retrySearch() {
        submitSearch()
    }

    func clearSearch() {
        searchTask?.cancel()
        loadMoreTask?.cancel()
        query = ""
        lastSearchedQuery = ""
        tracks = []
        isLoading = false
        isLoadingMore = false
        errorMessage = nil
        resetPagingState()
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasSearchedCurrentQuery: Bool {
        hasQuery && trimmedQuery == lastSearchedQuery
    }

    func loadMoreIfNeeded(currentTrackID: SpotifySimpleTrack.ID) {
        guard hasSearchedCurrentQuery else { return }
        guard hasMoreResults else { return }
        guard !isLoading, !isLoadingMore else { return }
        guard let lastTrackID = tracks.last?.id, lastTrackID == currentTrackID else { return }

        let queryForPaging = lastSearchedQuery
        loadMoreTask?.cancel()
        loadMoreTask = Task { [weak self] in
            await self?.search(
                query: queryForPaging,
                offset: self?.nextOffset ?? 0,
                mode: .pagination
            )
        }
    }

    private func search(query: String, offset: Int, mode: SearchMode) async {
        guard !query.isEmpty else {
            tracks = []
            errorMessage = nil
            isLoading = false
            isLoadingMore = false
            resetPagingState()
            return
        }

        switch mode {
        case .initial:
            isLoading = true
            errorMessage = nil
        case .pagination:
            isLoadingMore = true
        }
        defer {
            switch mode {
            case .initial:
                isLoading = false
            case .pagination:
                isLoadingMore = false
            }
        }

        do {
            let fetchedTracks = try await spotifyService.searchTracks(
                query: query,
                limit: pageSize,
                offset: offset
            )

            switch mode {
            case .initial:
                tracks = fetchedTracks
            case .pagination:
                let existingTrackIDs = Set(tracks.map(\.id))
                let newTracks = fetchedTracks.filter { !existingTrackIDs.contains($0.id) }
                tracks.append(contentsOf: newTracks)
                if fetchedTracks.isEmpty || newTracks.isEmpty {
                    hasMoreResults = false
                }
            }

            nextOffset = offset + fetchedTracks.count
            if fetchedTracks.count < pageSize {
                hasMoreResults = false
            }
        } catch {
            if Task.isCancelled { return }
            switch mode {
            case .initial:
                tracks = []
                errorMessage = resolveErrorMessage(from: error)
            case .pagination:
                hasMoreResults = false
            }
        }
    }

    private func resetPagingState() {
        nextOffset = 0
        hasMoreResults = true
    }

    private enum SearchMode {
        case initial
        case pagination
    }

    private func resolveErrorMessage(from error: Error) -> String {
        if let spotifyError = error as? SpotifyServiceError {
            return spotifyError.errorDescription ?? "Spotify 검색에 실패했어요."
        }

        if let localizedError = error as? LocalizedError {
            return localizedError.errorDescription ?? "Spotify 검색에 실패했어요."
        }

        return "Spotify 검색에 실패했어요."
    }
}
