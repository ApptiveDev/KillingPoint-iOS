import Foundation

@MainActor
final class FeedViewModel: ObservableObject {
    @Published private(set) var feeds: [DiaryFeedModel] = []
    @Published private(set) var isLoadingInitial = false
    @Published private(set) var isLoadingMore = false
    @Published var errorMessage: String?

    private let diaryService: DiaryServicing
    private var hasLoadedInitialData = false
    private var nextPage = DiaryService.defaultPage
    private var hasNextPage = true

    init(diaryService: DiaryServicing = DiaryService()) {
        self.diaryService = diaryService
    }

    func loadInitialDataIfNeeded() async {
        guard !hasLoadedInitialData else { return }
        await refresh()
    }

    func refresh() async {
        guard !isLoadingInitial else { return }
        isLoadingInitial = true
        errorMessage = nil
        defer { isLoadingInitial = false }

        do {
            let response = try await diaryService.fetchMyFeeds(
                page: DiaryService.defaultPage,
                size: DiaryService.defaultSize
            )
            feeds = response.content
            updatePaging(from: response)
            hasLoadedInitialData = true
        } catch {
            if isRequestCancelled(error) { return }
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    func loadMoreIfNeeded(currentDiaryId: Int) async {
        guard feeds.last?.diaryId == currentDiaryId else { return }
        guard hasNextPage else { return }
        guard !isLoadingInitial, !isLoadingMore else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let response = try await diaryService.fetchMyFeeds(
                page: nextPage,
                size: DiaryService.defaultSize
            )
            appendFeeds(with: response.content)
            updatePaging(from: response)
        } catch {
            if isRequestCancelled(error) { return }
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    func toggleLike(diaryId: Int) async {
        guard let index = feeds.firstIndex(where: { $0.diaryId == diaryId }) else { return }
        let originalFeed = feeds[index]
        let toggledIsLiked = !originalFeed.isLiked
        let optimisticLikeCount = max(originalFeed.likeCount + (toggledIsLiked ? 1 : -1), 0)
        feeds[index] = originalFeed.replacingInteraction(
            isLiked: toggledIsLiked,
            likeCount: optimisticLikeCount
        )

        do {
            let response = try await diaryService.toggleDiaryLike(diaryId: diaryId)
            guard let refreshedIndex = feeds.firstIndex(where: { $0.diaryId == diaryId }) else { return }
            let current = feeds[refreshedIndex]
            let confirmedLikeCount = max(
                current.likeCount + (response.isLiked == current.isLiked ? 0 : (response.isLiked ? 1 : -1)),
                0
            )
            feeds[refreshedIndex] = current.replacingInteraction(
                isLiked: response.isLiked,
                likeCount: confirmedLikeCount
            )
        } catch {
            if isRequestCancelled(error) { return }
            if let rollbackIndex = feeds.firstIndex(where: { $0.diaryId == diaryId }) {
                feeds[rollbackIndex] = originalFeed
            }
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    func toggleStore(diaryId: Int) async {
        guard let index = feeds.firstIndex(where: { $0.diaryId == diaryId }) else { return }
        let originalFeed = feeds[index]
        let toggledIsStored = !originalFeed.isStored
        feeds[index] = originalFeed.replacingInteraction(isStored: toggledIsStored)

        do {
            let response = try await diaryService.toggleDiaryStore(diaryId: diaryId)
            guard let refreshedIndex = feeds.firstIndex(where: { $0.diaryId == diaryId }) else { return }
            feeds[refreshedIndex] = feeds[refreshedIndex].replacingInteraction(isStored: response.isStored)
        } catch {
            if isRequestCancelled(error) { return }
            if let rollbackIndex = feeds.firstIndex(where: { $0.diaryId == diaryId }) {
                feeds[rollbackIndex] = originalFeed
            }
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    private func appendFeeds(with newFeeds: [DiaryFeedModel]) {
        let existingIDs = Set(feeds.map(\.id))
        let filtered = newFeeds.filter { !existingIDs.contains($0.id) }
        feeds.append(contentsOf: filtered)
    }

    private func updatePaging(from response: MyDiaryFeedsResponse) {
        nextPage = max(response.page.number, 0) + 1
        let totalPages = max(response.page.totalPages, 0)
        let hasNextByPage = nextPage < totalPages
        let hasNextByCount = response.content.count >= DiaryService.defaultSize
        hasNextPage = hasNextByPage || hasNextByCount
    }

    private func resolveErrorMessage(from error: Error) -> String {
        if let diaryError = error as? DiaryServiceError {
            return diaryError.errorDescription ?? "피드 목록을 불러오지 못했어요."
        }

        if let apiError = error as? APIClientError {
            return apiError.errorDescription ?? "요청 처리에 실패했어요."
        }

        if let localizedError = error as? LocalizedError {
            return localizedError.errorDescription ?? "요청 처리에 실패했어요."
        }

        return "요청 처리에 실패했어요."
    }

    private func isRequestCancelled(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
