import Foundation

@MainActor
final class SocialViewModel: ObservableObject {
    @Published private(set) var myPickUsers: [SubscribeUserModel] = []
    @Published private(set) var myFandomUsers: [SubscribeUserModel] = []
    @Published private(set) var myPickTotalCount = 0
    @Published private(set) var myFandomTotalCount = 0
    @Published private(set) var isLoadingMyPick = false
    @Published private(set) var isLoadingMyFandom = false
    @Published private(set) var isLoadingMoreMyPick = false
    @Published private(set) var isLoadingMoreMyFandom = false
    @Published var errorMessage: String?

    private let userService: UserServicing
    private let subscribeService: SubscribeServicing
    private var myUserID: Int?
    private var myPickNextPage = SubscribeService.defaultPage
    private var myFandomNextPage = SubscribeService.defaultPage
    private var hasNextMyPickPage = true
    private var hasNextMyFandomPage = true
    private var isRefreshing = false

    init(
        userService: UserServicing = UserService(),
        subscribeService: SubscribeServicing = SubscribeService()
    ) {
        self.userService = userService
        self.subscribeService = subscribeService
    }

    func loadInitialDataIfNeeded() async {
        await refresh()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        errorMessage = nil
        resetPagingState()

        do {
            let myUser = try await userService.fetchMyUser()
            myUserID = myUser.userId

            async let subscribers: SubscribeListResponse = loadSubscribers(
                userId: myUser.userId,
                page: SubscribeService.defaultPage,
                loadingMode: .initial
            )
            async let subscribes: SubscribeListResponse = loadSubscribes(
                userId: myUser.userId,
                page: SubscribeService.defaultPage,
                loadingMode: .initial
            )
            let (subscriberResponse, subscribeResponse) = try await (subscribers, subscribes)

            myPickUsers = subscribeResponse.content
            myFandomUsers = subscriberResponse.content
            updateMyPickPaging(from: subscribeResponse)
            updateMyFandomPaging(from: subscriberResponse)
        } catch {
            if isRequestCancelled(error) { return }
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    func loadMoreMyPickIfNeeded(currentUserId: Int) async {
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
            appendMyPickUsers(with: response.content)
            updateMyPickPaging(from: response)
        } catch {
            if isRequestCancelled(error) { return }
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    func loadMoreMyFandomIfNeeded(currentUserId: Int) async {
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
            appendMyFandomUsers(with: response.content)
            updateMyFandomPaging(from: response)
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

    private func appendMyPickUsers(with newUsers: [SubscribeUserModel]) {
        let existingIDs = Set(myPickUsers.map(\.userId))
        let filtered = newUsers.filter { !existingIDs.contains($0.userId) }
        myPickUsers.append(contentsOf: filtered)
    }

    private func appendMyFandomUsers(with newUsers: [SubscribeUserModel]) {
        let existingIDs = Set(myFandomUsers.map(\.userId))
        let filtered = newUsers.filter { !existingIDs.contains($0.userId) }
        myFandomUsers.append(contentsOf: filtered)
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

    private func resetPagingState() {
        myPickUsers = []
        myFandomUsers = []
        myPickTotalCount = 0
        myFandomTotalCount = 0
        myPickNextPage = SubscribeService.defaultPage
        myFandomNextPage = SubscribeService.defaultPage
        hasNextMyPickPage = true
        hasNextMyFandomPage = true
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
        }
    }

    private enum SocialSection {
        case myPick
        case myFandom
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
