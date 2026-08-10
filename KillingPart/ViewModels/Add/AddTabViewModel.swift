import Foundation

@MainActor
final class AddTabViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var tracks: [SpotifySimpleTrack] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published var errorMessage: String?

    private let spotifyService: SpotifyServicing
    private let itunesService: ITunesServicing
    private var searchTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?
    private var lastSearchedQuery = ""
    private let pageSize = 10
    private var nextOffset = 0
    private var hasMoreResults = true

    init(
        spotifyService: SpotifyServicing = SpotifyService(),
        itunesService: ITunesServicing = ITunesService()
    ) {
        self.spotifyService = spotifyService
        self.itunesService = itunesService
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
            let fetchedTracks = try await fetchTracks(
                query: query,
                limit: pageSize,
                offset: offset
            )

            switch mode {
            case .initial:
                tracks = fetchedTracks
            case .pagination:
                let existingTrackKeys = Set(tracks.map { normalizedTrackIdentity(for: $0) })
                let newTracks = fetchedTracks.filter { !existingTrackKeys.contains(normalizedTrackIdentity(for: $0)) }
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

    private func fetchTracks(
        query: String,
        limit: Int,
        offset: Int
    ) async throws -> [SpotifySimpleTrack] {
        let safeLimit = max(limit, 1)
        let safeOffset = max(offset, 0)

        async let spotifyResult = fetchSpotifyTracks(
            query: query,
            limit: safeLimit,
            offset: safeOffset
        )
        async let iTunesResult = fetchITunesTracks(
            query: query,
            limit: max(safeLimit * 2, safeLimit),
            offset: safeOffset
        )

        let spotifyOutcome = await spotifyResult
        let iTunesOutcome = await iTunesResult

        // 검색 정확도는 Spotify가 우수하므로 표시 순서는 Spotify를 primary로 유지하고,
        // 추천용 musicMetadata는 같은 곡의 iTunes 결과에서 찾아 채워 넣는다.
        let mergedTracks = mergeTracks(
            primary: spotifyOutcome.tracks,
            secondary: iTunesOutcome.tracks,
            metadataSource: iTunesOutcome.tracks,
            limit: safeLimit
        )

        let iTunesWithMetadata = iTunesOutcome.tracks.filter { $0.musicMetadata != nil }.count
        let mergedWithMetadata = mergedTracks.filter { $0.musicMetadata != nil }.count
        print(
            "[Search] query=\"\(query)\" "
            + "spotify=\(spotifyOutcome.tracks.count) "
            + "itunes=\(iTunesOutcome.tracks.count)(meta:\(iTunesWithMetadata)) "
            + "merged=\(mergedTracks.count)(meta:\(mergedWithMetadata))"
        )

        if !mergedTracks.isEmpty {
            return mergedTracks
        }

        if spotifyOutcome.didSucceed || iTunesOutcome.didSucceed {
            return []
        }

        if let spotifyError = spotifyOutcome.error {
            throw spotifyError
        }

        if let iTunesError = iTunesOutcome.error {
            throw iTunesError
        }

        return []
    }

    private func fetchSpotifyTracks(
        query: String,
        limit: Int,
        offset: Int
    ) async -> (tracks: [SpotifySimpleTrack], error: Error?, didSucceed: Bool) {
        do {
            let tracks = try await spotifyService.searchTracks(
                query: query,
                limit: limit,
                offset: offset
            )
            return (tracks, nil, true)
        } catch {
            return ([], error, false)
        }
    }

    private func fetchITunesTracks(
        query: String,
        limit: Int,
        offset: Int
    ) async -> (tracks: [SpotifySimpleTrack], error: Error?, didSucceed: Bool) {
        do {
            let tracks = try await itunesService.searchTracks(
                query: query,
                limit: limit,
                offset: offset
            )
            return (tracks, nil, true)
        } catch {
            return ([], error, false)
        }
    }

    private func mergeTracks(
        primary: [SpotifySimpleTrack],
        secondary: [SpotifySimpleTrack],
        metadataSource: [SpotifySimpleTrack] = [],
        limit: Int
    ) -> [SpotifySimpleTrack] {
        let metadataByKey = metadataLookup(from: metadataSource)

        var merged: [SpotifySimpleTrack] = []
        var dedupeKeys = Set<String>()

        for track in primary + secondary {
            let key = normalizedTrackIdentity(for: track)
            guard dedupeKeys.insert(key).inserted else { continue }
            merged.append(enrichedTrack(track, key: key, metadataByKey: metadataByKey))
            if merged.count == limit {
                break
            }
        }

        return merged
    }

    private func metadataLookup(
        from tracks: [SpotifySimpleTrack]
    ) -> (byIdentity: [String: MusicMetadata], byTitle: [String: MusicMetadata], byBaseTitle: [String: MusicMetadata]) {
        var byIdentity: [String: MusicMetadata] = [:]
        var byTitle: [String: MusicMetadata] = [:]
        var byBaseTitle: [String: MusicMetadata] = [:]
        for track in tracks {
            guard let metadata = track.musicMetadata else { continue }
            let identityKey = normalizedTrackIdentity(for: track)
            if byIdentity[identityKey] == nil {
                byIdentity[identityKey] = metadata
            }
            // 아티스트 표기가 서비스마다 달라(예: "스윙스" vs "Swings") 제목만으로도 보조 매칭한다.
            let titleKey = normalizedIdentityComponent(track.title)
            if byTitle[titleKey] == nil {
                byTitle[titleKey] = metadata
            }
            // 부제/피처링 표기(예: "파급효과 (Ripple Effect)" vs "파급효과")를 제거한 기본 제목으로도 매칭한다.
            let baseKey = baseTitleKey(from: track.title)
            if !baseKey.isEmpty, byBaseTitle[baseKey] == nil {
                byBaseTitle[baseKey] = metadata
            }
        }
        return (byIdentity, byTitle, byBaseTitle)
    }

    private func baseTitleKey(from title: String) -> String {
        let withoutBrackets = title
            .replacingOccurrences(of: "\\(.*?\\)", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\[.*?\\]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "feat\\..*", with: "", options: [.regularExpression, .caseInsensitive])
        return normalizedIdentityComponent(withoutBrackets)
    }

    private func enrichedTrack(
        _ track: SpotifySimpleTrack,
        key: String,
        metadataByKey: (byIdentity: [String: MusicMetadata], byTitle: [String: MusicMetadata], byBaseTitle: [String: MusicMetadata])
    ) -> SpotifySimpleTrack {
        guard track.musicMetadata == nil else { return track }

        let titleKey = normalizedIdentityComponent(track.title)
        let baseKey = baseTitleKey(from: track.title)
        let resolvedMetadata = metadataByKey.byIdentity[key]
            ?? metadataByKey.byTitle[titleKey]
            ?? (baseKey.isEmpty ? nil : metadataByKey.byBaseTitle[baseKey])
        guard let metadata = resolvedMetadata else {
            return track
        }

        return SpotifySimpleTrack(
            id: track.id,
            title: track.title,
            artist: track.artist,
            albumImageUrl: track.albumImageUrl,
            albumId: track.albumId,
            musicMetadata: metadata
        )
    }

    private func normalizedTrackIdentity(for track: SpotifySimpleTrack) -> String {
        "\(normalizedIdentityComponent(track.title))|\(normalizedIdentityComponent(track.artist))"
    }

    private func normalizedIdentityComponent(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
    }

    private enum SearchMode {
        case initial
        case pagination
    }

    private func resolveErrorMessage(from error: Error) -> String {
        if let spotifyError = error as? SpotifyServiceError {
            return spotifyError.errorDescription ?? "음악 검색에 실패했어요."
        }

        if let itunesError = error as? ITunesServiceError {
            return itunesError.errorDescription ?? "음악 검색에 실패했어요."
        }

        if let localizedError = error as? LocalizedError {
            return localizedError.errorDescription ?? "음악 검색에 실패했어요."
        }

        return "음악 검색에 실패했어요."
    }
}
