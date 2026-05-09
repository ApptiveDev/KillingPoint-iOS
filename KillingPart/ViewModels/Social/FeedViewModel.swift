import Foundation

@MainActor
final class FeedViewModel: ObservableObject {
    enum FeedSource {
        case myFeeds
        case random
    }

    @Published private(set) var feeds: [DiaryFeedModel] = []
    @Published private(set) var isLoadingInitial = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var likeUsers: [UserModel] = []
    @Published private(set) var isLoadingLikeUsers = false
    @Published private(set) var isLoadingMoreLikeUsers = false
    @Published private(set) var isReportingDiary = false
    @Published private(set) var isBlockingUser = false
    @Published var errorMessage: String?
    @Published var likeUsersErrorMessage: String?
    @Published var reportErrorMessage: String?

    private let diaryService: DiaryServicing
    private let userService: UserServicing
    private let feedSource: FeedSource
    private var hasLoadedInitialData = false
    private var nextPage = DiaryService.defaultPage
    private var hasNextPage = true
    private var isRefreshingInteractions = false
    private var lastInteractionRefreshAt: Date?
    private let interactionRefreshCooldown: TimeInterval = 0.75
    private let likeUsersPageSize = 20
    private var activeLikeUsersDiaryId: Int?
    private var activeLikeUsersSearchCond: String?
    private var likeUsersNextPage = DiaryService.defaultPage
    private var hasNextLikeUsersPage = true
    private var likeUsersRequestID = 0

    init(
        diaryService: DiaryServicing = DiaryService(),
        userService: UserServicing = UserService(),
        feedSource: FeedSource = .myFeeds
    ) {
        self.diaryService = diaryService
        self.userService = userService
        self.feedSource = feedSource
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
            let response = try await fetchFeeds(
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

    func refreshLoadedFeedInteractionsIfNeeded(force: Bool = false) async {
        guard hasLoadedInitialData else {
            await loadInitialDataIfNeeded()
            return
        }
        guard !feeds.isEmpty else { return }
        guard !isRefreshingInteractions else { return }

        if !force,
           let lastInteractionRefreshAt,
           Date().timeIntervalSince(lastInteractionRefreshAt) < interactionRefreshCooldown {
            return
        }

        isRefreshingInteractions = true
        defer {
            isRefreshingInteractions = false
            lastInteractionRefreshAt = Date()
        }

        do {
            let loadedPageCount: Int
            switch feedSource {
            case .myFeeds:
                loadedPageCount = max(
                    1,
                    Int(ceil(Double(feeds.count) / Double(max(DiaryService.defaultSize, 1))))
                )
            case .random:
                loadedPageCount = 1
            }

            var latestByDiaryId: [Int: DiaryFeedModel] = [:]
            var page = DiaryService.defaultPage

            for _ in 0..<loadedPageCount {
                let response = try await fetchFeeds(
                    page: page,
                    size: DiaryService.defaultSize
                )
                response.content.forEach { latestByDiaryId[$0.diaryId] = $0 }

                let nextPage = max(response.page.number, 0) + 1
                let totalPages = max(response.page.totalPages, 0)
                let hasNextByPage = nextPage < totalPages
                let hasNextByCount = response.content.count >= DiaryService.defaultSize
                let hasNext = hasNextByPage || hasNextByCount

                guard hasNext else { break }
                page = nextPage
            }

            guard !latestByDiaryId.isEmpty else { return }
            feeds = feeds.map { feed in
                guard let latestFeed = latestByDiaryId[feed.diaryId] else { return feed }
                return feed.replacingInteraction(
                    isLiked: latestFeed.isLiked,
                    isStored: latestFeed.isStored,
                    likeCount: latestFeed.likeCount
                )
            }
        } catch {
            if isRequestCancelled(error) { return }
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    func loadLikeUsers(diaryId: Int, searchCond: String? = nil) async {
        likeUsersRequestID += 1
        let requestID = likeUsersRequestID
        activeLikeUsersDiaryId = diaryId
        activeLikeUsersSearchCond = normalizedSearchCond(searchCond)
        likeUsers = []
        likeUsersErrorMessage = nil
        likeUsersNextPage = DiaryService.defaultPage
        hasNextLikeUsersPage = true
        isLoadingLikeUsers = true
        defer {
            if likeUsersRequestID == requestID {
                isLoadingLikeUsers = false
            }
        }

        do {
            let response = try await diaryService.fetchDiaryLikeUsers(
                diaryId: diaryId,
                searchCond: activeLikeUsersSearchCond,
                page: DiaryService.defaultPage,
                size: likeUsersPageSize
            )
            guard likeUsersRequestID == requestID else { return }
            likeUsers = response.content
            updateLikeUsersPaging(from: response)
        } catch {
            guard likeUsersRequestID == requestID else { return }
            if isRequestCancelled(error) { return }
            likeUsersErrorMessage = resolveErrorMessage(from: error)
        }
    }

    func loadMoreLikeUsersIfNeeded(currentUserId: Int) async {
        guard likeUsers.last?.userId == currentUserId else { return }
        guard hasNextLikeUsersPage else { return }
        guard !isLoadingLikeUsers, !isLoadingMoreLikeUsers else { return }
        guard let activeLikeUsersDiaryId else { return }

        isLoadingMoreLikeUsers = true
        defer { isLoadingMoreLikeUsers = false }

        do {
            let response = try await diaryService.fetchDiaryLikeUsers(
                diaryId: activeLikeUsersDiaryId,
                searchCond: activeLikeUsersSearchCond,
                page: likeUsersNextPage,
                size: likeUsersPageSize
            )
            appendLikeUsers(with: response.content)
            updateLikeUsersPaging(from: response)
        } catch {
            if isRequestCancelled(error) { return }
            likeUsersErrorMessage = resolveErrorMessage(from: error)
        }
    }

    func retryLikeUsersLoading() async {
        guard let activeLikeUsersDiaryId else { return }
        await loadLikeUsers(
            diaryId: activeLikeUsersDiaryId,
            searchCond: activeLikeUsersSearchCond
        )
    }

    func clearLikeUsersState() {
        likeUsersRequestID += 1
        activeLikeUsersDiaryId = nil
        activeLikeUsersSearchCond = nil
        likeUsers = []
        likeUsersErrorMessage = nil
        likeUsersNextPage = DiaryService.defaultPage
        hasNextLikeUsersPage = true
        isLoadingLikeUsers = false
        isLoadingMoreLikeUsers = false
    }

    func clearDiaryReportState() {
        reportErrorMessage = nil
    }

    func loadMoreIfNeeded(currentDiaryId: Int) async {
        guard feeds.last?.diaryId == currentDiaryId else { return }
        guard hasNextPage else { return }
        guard !isLoadingInitial, !isLoadingMore else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let response = try await fetchFeeds(
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

    func reportDiary(diaryId: Int, content: String) async -> Bool {
        guard !isReportingDiary else { return false }

        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            reportErrorMessage = "빈칸은 입력할 수 없습니다."
            return false
        }
        guard trimmedContent.count <= 200 else {
            reportErrorMessage = "신고 내용은 1자 이상 200자 이하입니다."
            return false
        }

        reportErrorMessage = nil
        isReportingDiary = true
        defer { isReportingDiary = false }

        do {
            try await diaryService.reportDiary(diaryId: diaryId, content: trimmedContent)
            return true
        } catch {
            if isRequestCancelled(error) { return false }
            reportErrorMessage = resolveErrorMessage(from: error)
            return false
        }
    }
    
    func blockUser(blockedId: Int) async -> Bool {
        guard blockedId > 0 else { return false }
        guard !isBlockingUser else { return false }

        errorMessage = nil
        isBlockingUser = true
        defer { isBlockingUser = false }

        do {
            try await userService.blockUser(blockedId: blockedId)
            feeds.removeAll { $0.userId == blockedId }
            return true
        } catch {
            if isRequestCancelled(error) { return false }
            errorMessage = resolveErrorMessage(from: error)
            return false
        }
    }

    private func appendFeeds(with newFeeds: [DiaryFeedModel]) {
        let existingIDs = Set(feeds.map(\.id))
        let filtered = newFeeds.filter { !existingIDs.contains($0.id) }
        feeds.append(contentsOf: filtered)
    }

    private func appendLikeUsers(with newUsers: [UserModel]) {
        let existingIDs = Set(likeUsers.map(\.userId))
        let filtered = newUsers.filter { !existingIDs.contains($0.userId) }
        likeUsers.append(contentsOf: filtered)
    }

    private func fetchFeeds(page: Int, size: Int) async throws -> MyDiaryFeedsResponse {
        switch feedSource {
        case .myFeeds:
            return try await diaryService.fetchMyFeeds(page: page, size: size)
        case .random:
            return try await diaryService.fetchRandomDiaries().asMyDiaryFeedsResponse
        }
    }

    private func updatePaging(from response: MyDiaryFeedsResponse) {
        switch feedSource {
        case .myFeeds:
            nextPage = max(response.page.number, 0) + 1
            let totalPages = max(response.page.totalPages, 0)
            let hasNextByPage = nextPage < totalPages
            let hasNextByCount = response.content.count >= DiaryService.defaultSize
            hasNextPage = hasNextByPage || hasNextByCount
        case .random:
            nextPage = DiaryService.defaultPage
            hasNextPage = !response.content.isEmpty
        }
    }

    private func updateLikeUsersPaging(from response: UserSearchResponse) {
        likeUsersNextPage = max(response.page.number, 0) + 1
        let totalPages = max(response.page.totalPages, 0)
        let hasNextByPage = likeUsersNextPage < totalPages
        let hasNextByCount = response.content.count >= likeUsersPageSize
        hasNextLikeUsersPage = hasNextByPage || hasNextByCount
    }

    private func normalizedSearchCond(_ searchCond: String?) -> String? {
        let trimmed = searchCond?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func resolveErrorMessage(from error: Error) -> String {
        if let diaryError = error as? DiaryServiceError {
            return diaryError.errorDescription ?? "피드 목록을 불러오지 못했어요."
        }
        
        if let userError = error as? UserServiceError {
            return userError.errorDescription ?? "요청 처리에 실패했어요."
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
