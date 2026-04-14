import Foundation

@MainActor
final class SocialViewModel: ObservableObject {
    @Published private(set) var myPickUsers: [SubscribeUserModel] = []
    @Published private(set) var myFandomUsers: [SubscribeUserModel] = []
    @Published private(set) var searchedUsers: [UserModel] = []
    @Published private(set) var myPickTotalCount = 0
    @Published private(set) var myFandomTotalCount = 0
    @Published private(set) var searchedUserTotalCount = 0
    @Published private(set) var isLoadingMyPick = false
    @Published private(set) var isLoadingMyFandom = false
    @Published private(set) var isLoadingSearchedUsers = false
    @Published private(set) var isLoadingMoreMyPick = false
    @Published private(set) var isLoadingMoreMyFandom = false
    @Published private(set) var isLoadingMoreSearchedUsers = false
    @Published var errorMessage: String?
    @Published var currentSearchQuery = ""

    private let userService: UserServicing
    private let subscribeService: SubscribeServicing
    private let diaryService: DiaryServicing
    private var myUserID: Int?
    private var hasLoadedInitialData = false

    private var myPickNextPage = SubscribeService.defaultPage
    private var myFandomNextPage = SubscribeService.defaultPage
    private var searchedUsersNextPage = UserService.defaultPage
    private var hasNextMyPickPage = true
    private var hasNextMyFandomPage = true
    private var hasNextSearchedUsersPage = true
    private var isRefreshing = false
    private let maxPaginationRecoveryAttempts = 3
    private let maxAutoPaginationStallAttempts = 6

    init(
        userService: UserServicing = UserService(),
        subscribeService: SubscribeServicing = SubscribeService(),
        diaryService: DiaryServicing = DiaryService()
    ) {
        self.userService = userService
        self.subscribeService = subscribeService
        self.diaryService = diaryService
    }

    var isSearching: Bool {
        !currentSearchQuery.isEmpty
    }

    func loadInitialDataIfNeeded() async {
        guard !hasLoadedInitialData else { return }
        await refreshDefaultLists()
    }

    func refreshCurrentList() async {
        if isSearching {
            await searchUsers(with: currentSearchQuery)
        } else {
            await refreshDefaultLists()
        }
    }

    func refreshDefaultLists() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        errorMessage = nil
        resetDefaultPagingState()

        do {
            let myUser = try await userService.fetchMyUser()
            myUserID = myUser.userId

            async let subscribersTask: SubscribeListResponse = loadSubscribers(
                userId: myUser.userId,
                page: SubscribeService.defaultPage,
                loadingMode: .initial
            )
            async let subscribesTask: SubscribeListResponse = loadSubscribes(
                userId: myUser.userId,
                page: SubscribeService.defaultPage,
                loadingMode: .initial
            )
            let (subscriberResponse, subscribeResponse) = try await (subscribersTask, subscribesTask)
            let initialPage = SubscribeService.defaultPage

            myPickUsers = subscribeResponse.content
            myFandomUsers = subscriberResponse.content
            updateMyPickPaging(from: subscribeResponse, requestedPage: initialPage)
            updateMyFandomPaging(from: subscriberResponse, requestedPage: initialPage)
            hasLoadedInitialData = true
            await preloadAllDefaultPagesIfNeeded()
        } catch {
            if isRequestCancelled(error) { return }
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    func searchUsers(with query: String) async {
        currentSearchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentSearchQuery.isEmpty else {
            clearSearchState()
            if !hasLoadedInitialData {
                await refreshDefaultLists()
            }
            return
        }

        errorMessage = nil
        resetSearchPagingState()

        do {
            let response = try await loadSearchedUsers(
                page: UserService.defaultPage,
                loadingMode: .initial
            )
            searchedUsers = response.content
            updateSearchPaging(from: response)
        } catch {
            if isRequestCancelled(error) { return }
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    func loadMoreCurrentSectionIfNeeded(currentUserId: Int, isMyPickSection: Bool) async {
        if isSearching {
            await loadMoreSearchedUsersIfNeeded(currentUserId: currentUserId)
            return
        }

        if isMyPickSection {
            await loadMoreMyPickIfNeeded(currentUserId: currentUserId)
        } else {
            await loadMoreMyFandomIfNeeded(currentUserId: currentUserId)
        }
    }

    func users(for isMyPickSection: Bool) -> [SocialListUser] {
        if isSearching {
            return searchedUsers.map { .searched($0) }
        }

        let source = isMyPickSection ? myPickUsers : myFandomUsers
        return source.map { .subscribed($0) }
    }

    func isLoading(for isMyPickSection: Bool) -> Bool {
        if isSearching {
            return isLoadingSearchedUsers
        }
        return isMyPickSection ? isLoadingMyPick : isLoadingMyFandom
    }

    func isLoadingMore(for isMyPickSection: Bool) -> Bool {
        if isSearching {
            return isLoadingMoreSearchedUsers
        }
        return isMyPickSection ? isLoadingMoreMyPick : isLoadingMoreMyFandom
    }

    func totalCount(for isMyPickSection: Bool) -> Int {
        if isSearching {
            return searchedUserTotalCount
        }
        return isMyPickSection ? myPickTotalCount : myFandomTotalCount
    }

    func makeSocialMyCollectionViewModel(for user: SocialListUser, fallbackIsMyPick: Bool?) -> SocialMyCollectionViewModel {
        let resolvedUser: UserModel
        switch user {
        case .subscribed(let subscribedUser):
            resolvedUser = UserModel(from: subscribedUser, isMyPick: fallbackIsMyPick)
        case .searched(let searchedUser):
            resolvedUser = searchedUser
        }

        return makeSocialMyCollectionViewModel(for: resolvedUser)
    }

    func makeSocialMyCollectionViewModel(for user: UserModel) -> SocialMyCollectionViewModel {
        return SocialMyCollectionViewModel(
            initialUser: user,
            userService: userService,
            diaryService: diaryService,
            onToggleMyPick: { [self] userId, isCurrentlyMyPick in
                try await toggleMyPick(for: userId, isCurrentlyMyPick: isCurrentlyMyPick)
            }
        )
    }

    func toggleMyPick(for userId: Int, isCurrentlyMyPick: Bool) async throws {
        if isCurrentlyMyPick {
            try await subscribeService.unsubscribe(from: userId)
        } else {
            try await subscribeService.subscribe(to: userId)
        }
        await forceRefetchDefaultLists()
    }

    private func forceRefetchDefaultLists() async {
        hasLoadedInitialData = false
        await refreshDefaultLists()
    }

    private func loadMoreMyPickIfNeeded(currentUserId: Int) async {
        guard let myUserID else { return }
        guard myPickUsers.last?.userId == currentUserId else { return }
        guard hasNextMyPickPage else { return }
        guard !isLoadingMyPick, !isLoadingMoreMyPick else { return }

        do {
            var requestedPage = myPickNextPage
            var recoveryAttemptCount = 0

            while recoveryAttemptCount < maxPaginationRecoveryAttempts {
                let response = try await loadSubscribes(
                    userId: myUserID,
                    page: requestedPage,
                    loadingMode: .pagination
                )
                let appendedCount = appendUsers(to: &myPickUsers, with: response.content)
                updateMyPickPaging(from: response, requestedPage: requestedPage)

                if appendedCount > 0 {
                    return
                }

                guard hasNextMyPickPage else { return }
                guard !response.content.isEmpty else {
                    hasNextMyPickPage = false
                    return
                }

                let advancedPage = max(myPickNextPage, requestedPage + 1)
                guard advancedPage != requestedPage else { return }
                myPickNextPage = advancedPage
                requestedPage = advancedPage
                recoveryAttemptCount += 1
            }
        } catch {
            if isRequestCancelled(error) { return }
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    private func loadMoreMyFandomIfNeeded(currentUserId: Int) async {
        guard let myUserID else { return }
        guard myFandomUsers.last?.userId == currentUserId else { return }
        guard hasNextMyFandomPage else { return }
        guard !isLoadingMyFandom, !isLoadingMoreMyFandom else { return }

        do {
            var requestedPage = myFandomNextPage
            var recoveryAttemptCount = 0

            while recoveryAttemptCount < maxPaginationRecoveryAttempts {
                let response = try await loadSubscribers(
                    userId: myUserID,
                    page: requestedPage,
                    loadingMode: .pagination
                )
                let appendedCount = appendUsers(to: &myFandomUsers, with: response.content)
                updateMyFandomPaging(from: response, requestedPage: requestedPage)

                if appendedCount > 0 {
                    return
                }

                guard hasNextMyFandomPage else { return }
                guard !response.content.isEmpty else {
                    hasNextMyFandomPage = false
                    return
                }

                let advancedPage = max(myFandomNextPage, requestedPage + 1)
                guard advancedPage != requestedPage else { return }
                myFandomNextPage = advancedPage
                requestedPage = advancedPage
                recoveryAttemptCount += 1
            }
        } catch {
            if isRequestCancelled(error) { return }
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    private func preloadAllDefaultPagesIfNeeded() async {
        await preloadMyPickPagesIfNeeded()
        await preloadMyFandomPagesIfNeeded()
    }

    private func preloadMyPickPagesIfNeeded() async {
        var stallAttemptCount = 0

        while hasNextMyPickPage {
            guard let currentUserID = myPickUsers.last?.userId else {
                hasNextMyPickPage = false
                return
            }

            let previousCount = myPickUsers.count
            await loadMoreMyPickIfNeeded(currentUserId: currentUserID)

            if myPickUsers.count > previousCount {
                stallAttemptCount = 0
                continue
            }

            stallAttemptCount += 1
            guard stallAttemptCount < maxAutoPaginationStallAttempts else { return }
        }
    }

    private func preloadMyFandomPagesIfNeeded() async {
        var stallAttemptCount = 0

        while hasNextMyFandomPage {
            guard let currentUserID = myFandomUsers.last?.userId else {
                hasNextMyFandomPage = false
                return
            }

            let previousCount = myFandomUsers.count
            await loadMoreMyFandomIfNeeded(currentUserId: currentUserID)

            if myFandomUsers.count > previousCount {
                stallAttemptCount = 0
                continue
            }

            stallAttemptCount += 1
            guard stallAttemptCount < maxAutoPaginationStallAttempts else { return }
        }
    }

    private func loadMoreSearchedUsersIfNeeded(currentUserId: Int) async {
        guard searchedUsers.last?.userId == currentUserId else { return }
        guard hasNextSearchedUsersPage else { return }
        guard !isLoadingSearchedUsers, !isLoadingMoreSearchedUsers else { return }

        do {
            let response = try await loadSearchedUsers(
                page: searchedUsersNextPage,
                loadingMode: .pagination
            )
            appendUsers(to: &searchedUsers, with: response.content)
            updateSearchPaging(from: response)
        } catch {
            if isRequestCancelled(error) { return }
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    private func loadSubscribers(
        userId: Int,
        page: Int,
        loadingMode: LoadingMode
    ) async throws -> SubscribeListResponse {
        setLoadingState(for: .myFandom, mode: loadingMode, isLoading: true)
        defer { setLoadingState(for: .myFandom, mode: loadingMode, isLoading: false) }

        return try await subscribeService.fetchSubscribers(
            userId: userId,
            page: page,
            size: SubscribeService.defaultSize
        )
    }

    private func loadSubscribes(
        userId: Int,
        page: Int,
        loadingMode: LoadingMode
    ) async throws -> SubscribeListResponse {
        setLoadingState(for: .myPick, mode: loadingMode, isLoading: true)
        defer { setLoadingState(for: .myPick, mode: loadingMode, isLoading: false) }

        return try await subscribeService.fetchSubscribes(
            userId: userId,
            page: page,
            size: SubscribeService.defaultSize
        )
    }

    private func loadSearchedUsers(
        page: Int,
        loadingMode: LoadingMode
    ) async throws -> UserSearchResponse {
        setLoadingState(for: .search, mode: loadingMode, isLoading: true)
        defer { setLoadingState(for: .search, mode: loadingMode, isLoading: false) }

        return try await userService.searchUsers(
            searchCond: currentSearchQuery,
            page: page,
            size: UserService.defaultSize
        )
    }

    @discardableResult
    private func appendUsers(to target: inout [SubscribeUserModel], with newUsers: [SubscribeUserModel]) -> Int {
        let existingIDs = Set(target.map(\.userId))
        let filtered = newUsers.filter { !existingIDs.contains($0.userId) }
        target.append(contentsOf: filtered)
        return filtered.count
    }

    @discardableResult
    private func appendUsers(to target: inout [UserModel], with newUsers: [UserModel]) -> Int {
        let existingIDs = Set(target.map(\.userId))
        let filtered = newUsers.filter { !existingIDs.contains($0.userId) }
        target.append(contentsOf: filtered)
        return filtered.count
    }

    private func updateMyPickPaging(from response: SubscribeListResponse, requestedPage: Int) {
        myPickNextPage = max(requestedPage, SubscribeService.defaultPage) + 1
        let totalPages = max(response.page.totalPages, 0)
        let hasNextByPage = myPickNextPage < totalPages
        let hasNextByCount = response.content.count >= SubscribeService.defaultSize
        hasNextMyPickPage = hasNextByPage || hasNextByCount
        myPickTotalCount = max(response.page.totalElements, 0)
    }

    private func updateMyFandomPaging(from response: SubscribeListResponse, requestedPage: Int) {
        myFandomNextPage = max(requestedPage, SubscribeService.defaultPage) + 1
        let totalPages = max(response.page.totalPages, 0)
        let hasNextByPage = myFandomNextPage < totalPages
        let hasNextByCount = response.content.count >= SubscribeService.defaultSize
        hasNextMyFandomPage = hasNextByPage || hasNextByCount
        myFandomTotalCount = max(response.page.totalElements, 0)
    }

    private func updateSearchPaging(from response: UserSearchResponse) {
        searchedUsersNextPage = max(response.page.number, 0) + 1
        let totalPages = max(response.page.totalPages, 0)
        let hasNextByPage = searchedUsersNextPage < totalPages
        let hasNextByCount = response.content.count >= UserService.defaultSize
        hasNextSearchedUsersPage = hasNextByPage || hasNextByCount
        searchedUserTotalCount = max(response.page.totalElements, 0)
    }

    private func resetDefaultPagingState() {
        myPickUsers = []
        myFandomUsers = []
        myPickTotalCount = 0
        myFandomTotalCount = 0
        myPickNextPage = SubscribeService.defaultPage
        myFandomNextPage = SubscribeService.defaultPage
        hasNextMyPickPage = true
        hasNextMyFandomPage = true
    }

    private func resetSearchPagingState() {
        searchedUsers = []
        searchedUserTotalCount = 0
        searchedUsersNextPage = UserService.defaultPage
        hasNextSearchedUsersPage = true
    }

    private func clearSearchState() {
        currentSearchQuery = ""
        searchedUsers = []
        searchedUserTotalCount = 0
        searchedUsersNextPage = UserService.defaultPage
        hasNextSearchedUsersPage = true
    }

    private func setLoadingState(for section: SocialSection, mode: LoadingMode, isLoading: Bool) {
        switch (section, mode) {
        case (.myPick, .initial):
            isLoadingMyPick = isLoading
        case (.myPick, .pagination):
            isLoadingMoreMyPick = isLoading
        case (.myFandom, .initial):
            isLoadingMyFandom = isLoading
        case (.myFandom, .pagination):
            isLoadingMoreMyFandom = isLoading
        case (.search, .initial):
            isLoadingSearchedUsers = isLoading
        case (.search, .pagination):
            isLoadingMoreSearchedUsers = isLoading
        }
    }

    private enum SocialSection {
        case myPick
        case myFandom
        case search
    }

    private enum LoadingMode {
        case initial
        case pagination
    }

    private func resolveErrorMessage(from error: Error) -> String {
        if let subscribeError = error as? SubscribeServiceError {
            return subscribeError.errorDescription ?? "구독 목록을 불러오지 못했어요."
        }

        if let userError = error as? UserServiceError {
            return userError.errorDescription ?? "회원 정보를 불러오지 못했어요."
        }

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

enum SocialListUser: Identifiable {
    case subscribed(SubscribeUserModel)
    case searched(UserModel)

    var id: Int {
        switch self {
        case .subscribed(let user):
            return user.userId
        case .searched(let user):
            return user.userId
        }
    }

    var userId: Int {
        id
    }

    var displayName: String {
        switch self {
        case .subscribed(let user):
            return user.displayName
        case .searched(let user):
            return user.displayName
        }
    }

    var displayTag: String {
        switch self {
        case .subscribed(let user):
            return user.displayTag
        case .searched(let user):
            return user.displayTag
        }
    }

    var profileImageURL: URL? {
        switch self {
        case .subscribed(let user):
            return user.profileImageURL
        case .searched(let user):
            return user.profileImageURL
        }
    }

    var userModel: UserModel {
        switch self {
        case .subscribed(let user):
            return UserModel(from: user)
        case .searched(let user):
            return user
        }
    }
}
