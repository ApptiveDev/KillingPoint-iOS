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

            myPickUsers = subscribeResponse.content
            myFandomUsers = subscriberResponse.content
            updateMyPickPaging(from: subscribeResponse)
            updateMyFandomPaging(from: subscriberResponse)
            hasLoadedInitialData = true
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

    func makeSocialMyCollectionViewModel(for user: SocialListUser) -> SocialMyCollectionViewModel {
        let resolvedUser = user.userModel
        return SocialMyCollectionViewModel(
            initialUser: resolvedUser,
            userService: userService,
            diaryService: diaryService
        )
    }

    private func loadMoreMyPickIfNeeded(currentUserId: Int) async {
        guard let myUserID else { return }
        guard myPickUsers.last?.userId == currentUserId else { return }
        guard hasNextMyPickPage else { return }
        guard !isLoadingMyPick, !isLoadingMoreMyPick else { return }

        do {
            let response = try await loadSubscribes(
                userId: myUserID,
                page: myPickNextPage,
                loadingMode: .pagination
            )
            appendUsers(to: &myPickUsers, with: response.content)
            updateMyPickPaging(from: response)
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
            let response = try await loadSubscribers(
                userId: myUserID,
                page: myFandomNextPage,
                loadingMode: .pagination
            )
            appendUsers(to: &myFandomUsers, with: response.content)
            updateMyFandomPaging(from: response)
        } catch {
            if isRequestCancelled(error) { return }
            errorMessage = resolveErrorMessage(from: error)
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

    private func appendUsers(to target: inout [SubscribeUserModel], with newUsers: [SubscribeUserModel]) {
        let existingIDs = Set(target.map(\.userId))
        let filtered = newUsers.filter { !existingIDs.contains($0.userId) }
        target.append(contentsOf: filtered)
    }

    private func appendUsers(to target: inout [UserModel], with newUsers: [UserModel]) {
        let existingIDs = Set(target.map(\.userId))
        let filtered = newUsers.filter { !existingIDs.contains($0.userId) }
        target.append(contentsOf: filtered)
    }

    private func updateMyPickPaging(from response: SubscribeListResponse) {
        myPickNextPage = max(response.page.number, 0) + 1
        hasNextMyPickPage = myPickNextPage < max(response.page.totalPages, 0)
        myPickTotalCount = max(response.page.totalElements, 0)
    }

    private func updateMyFandomPaging(from response: SubscribeListResponse) {
        myFandomNextPage = max(response.page.number, 0) + 1
        hasNextMyFandomPage = myFandomNextPage < max(response.page.totalPages, 0)
        myFandomTotalCount = max(response.page.totalElements, 0)
    }

    private func updateSearchPaging(from response: UserSearchResponse) {
        searchedUsersNextPage = max(response.page.number, 0) + 1
        hasNextSearchedUsersPage = searchedUsersNextPage < max(response.page.totalPages, 0)
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
