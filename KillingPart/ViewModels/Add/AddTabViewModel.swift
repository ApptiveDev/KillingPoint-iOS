import Foundation

@MainActor
final class AddTabViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var tracks: [SpotifySimpleTrack] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let spotifyService: SpotifyServicing
    private var searchTask: Task<Void, Never>?
    private var lastSearchedQuery = ""

    init(spotifyService: SpotifyServicing = SpotifyService()) {
        self.spotifyService = spotifyService
    }

    deinit {
        searchTask?.cancel()
    }

    var hasQuery: Bool {
        !trimmedQuery.isEmpty
    }

    var shouldShowEmptyState: Bool {
        hasSearchedCurrentQuery && !isLoading && errorMessage == nil && tracks.isEmpty
    }

    func handleQueryChanged() {
        searchTask?.cancel()
        isLoading = false

        guard hasQuery else {
            lastSearchedQuery = ""
            tracks = []
            errorMessage = nil
            return
        }

        if !hasSearchedCurrentQuery {
            tracks = []
            errorMessage = nil
        }
    }

    func submitSearch() {
        searchTask?.cancel()

        guard hasQuery else {
            tracks = []
            errorMessage = nil
            isLoading = false
            return
        }

        let currentQuery = trimmedQuery
        lastSearchedQuery = currentQuery
        searchTask = Task { [weak self] in
            await self?.search(query: currentQuery)
        }
    }

    func retrySearch() {
        submitSearch()
    }

    func clearSearch() {
        searchTask?.cancel()
        query = ""
        lastSearchedQuery = ""
        tracks = []
        isLoading = false
        errorMessage = nil
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasSearchedCurrentQuery: Bool {
        hasQuery && trimmedQuery == lastSearchedQuery
    }

    private func search(query: String) async {
        guard !query.isEmpty else {
            tracks = []
            errorMessage = nil
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            tracks = try await spotifyService.searchTracks(query: query, limit: 10)
        } catch {
            if Task.isCancelled { return }
            tracks = []
            errorMessage = resolveErrorMessage(from: error)
        }
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
