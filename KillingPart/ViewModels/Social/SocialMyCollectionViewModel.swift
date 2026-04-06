import Foundation

@MainActor
final class SocialMyCollectionViewModel: ObservableObject {
    @Published private(set) var user: UserModel
    @Published private(set) var userStatics: UserStaticsModel?
    @Published private(set) var feeds: [DiaryFeedModel]
    @Published private(set) var isLoadingInitial = false
    @Published private(set) var isLoadingMoreFeeds = false
    @Published private(set) var connectionUsers: [SubscribeUserModel] = []
    @Published private(set) var isLoadingConnections = false
    @Published private(set) var isLoadingMoreConnections = false
    @Published var errorMessage: String?
    @Published var connectionErrorMessage: String?

    private let userService: UserServicing
    private let diaryService: DiaryServicing
    private let subscribeService: SubscribeServicing
    private let onToggleMyPick: (_ userId: Int, _ isCurrentlyMyPick: Bool) async throws -> Void

    private var hasLoadedInitialData = false
    private var nextFeedPage: Int
    private var hasNextFeedPage: Bool
    private var activeConnectionType: ConnectionType?
    private var nextConnectionPage = SubscribeService.defaultPage
    private var hasNextConnectionPage = true
    private var connectionRequestID = 0

    init(
        initialUser: UserModel,
        initialUserStatics: UserStaticsModel? = nil,
        initialFeeds: [DiaryFeedModel] = [],
        initialNextFeedPage: Int = DiaryService.defaultPage,
        initialHasNextFeedPage: Bool = true,
        userService: UserServicing = UserService(),
        diaryService: DiaryServicing = DiaryService(),
        subscribeService: SubscribeServicing = SubscribeService(),
        onToggleMyPick: @escaping (_ userId: Int, _ isCurrentlyMyPick: Bool) async throws -> Void = { _, _ in }
    ) {
        user = initialUser
        userStatics = initialUserStatics
        feeds = initialFeeds
        nextFeedPage = initialNextFeedPage
        hasNextFeedPage = initialHasNextFeedPage
        self.userService = userService
        self.diaryService = diaryService
        self.subscribeService = subscribeService
        self.onToggleMyPick = onToggleMyPick
    }

    var displayName: String {
        user.displayName
    }

    var displayTag: String {
        user.displayTag
    }

    var profileImageURL: URL? {
        user.profileImageURL
    }

    var killingPartStatText: String {
        "\(userStatics?.killingPartCount ?? 0)"
    }

    var fanStatText: String {
        "\(userStatics?.fanCount ?? 0)"
    }

    var pickStatText: String {
        "\(userStatics?.pickCount ?? 0)"
    }

    var isMyPick: Bool {
        user.isMyPick == true
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
            async let userStaticsTask = userService.fetchUserStatics(userId: user.userId)
            async let userFeedsTask = diaryService.fetchUserFeeds(
                userId: user.userId,
                page: DiaryService.defaultPage,
                size: DiaryService.defaultSize
            )
            let (fetchedUserStatics, feedResponse) = try await (userStaticsTask, userFeedsTask)
            userStatics = fetchedUserStatics
            feeds = feedResponse.content.map { $0.toDiaryFeedModel(user: user) }
            updateFeedPaging(from: feedResponse)
            hasLoadedInitialData = true
        } catch {
            if isRequestCancelled(error) { return }
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    func toggleMyPick() async {
        guard !isLoadingInitial else { return }
        errorMessage = nil

        do {
            let previousIsMyPick = isMyPick
            try await onToggleMyPick(user.userId, previousIsMyPick)
            user = UserModel(
                userId: user.userId,
                username: user.username,
                tag: user.tag,
                identifier: user.identifier,
                profileImageUrl: user.profileImageUrl,
                userRoleType: user.userRoleType,
                socialType: user.socialType,
                isMyPick: !previousIsMyPick
            )
            await refresh()
        } catch {
            if isRequestCancelled(error) { return }
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    func loadMoreFeedsIfNeeded(currentFeedId: Int) async {
        guard feeds.last?.diaryId == currentFeedId else { return }
        guard hasNextFeedPage else { return }
        guard !isLoadingInitial, !isLoadingMoreFeeds else { return }

        isLoadingMoreFeeds = true
        defer { isLoadingMoreFeeds = false }

        do {
            let response = try await diaryService.fetchUserFeeds(
                userId: user.userId,
                page: nextFeedPage,
                size: DiaryService.defaultSize
            )
            appendFeeds(with: response.content.map { $0.toDiaryFeedModel(user: user) })
            updateFeedPaging(from: response)
        } catch {
            if isRequestCancelled(error) { return }
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    func loadConnections(type: ConnectionType) async {
        connectionRequestID += 1
        let requestID = connectionRequestID
        activeConnectionType = type
        nextConnectionPage = SubscribeService.defaultPage
        hasNextConnectionPage = true
        connectionUsers = []
        connectionErrorMessage = nil
        isLoadingConnections = true
        defer { isLoadingConnections = false }

        do {
            let response = try await fetchConnections(type: type, page: SubscribeService.defaultPage)
            guard requestID == connectionRequestID else { return }
            connectionUsers = response.content
            updateConnectionPaging(from: response)
        } catch {
            guard requestID == connectionRequestID else { return }
            if isRequestCancelled(error) { return }
            connectionErrorMessage = resolveErrorMessage(from: error)
        }
    }

    func loadMoreConnectionsIfNeeded(currentUserId: Int) async {
        guard connectionUsers.last?.userId == currentUserId else { return }
        guard hasNextConnectionPage else { return }
        guard !isLoadingConnections, !isLoadingMoreConnections else { return }
        guard let activeConnectionType else { return }

        isLoadingMoreConnections = true
        defer { isLoadingMoreConnections = false }

        do {
            let response = try await fetchConnections(type: activeConnectionType, page: nextConnectionPage)
            appendConnectionUsers(with: response.content)
            updateConnectionPaging(from: response)
        } catch {
            if isRequestCancelled(error) { return }
            connectionErrorMessage = resolveErrorMessage(from: error)
        }
    }

    func refreshActiveConnections() async {
        guard let activeConnectionType else { return }
        await loadConnections(type: activeConnectionType)
    }

    func makeSocialMyCollectionViewModel(for user: SubscribeUserModel) -> SocialMyCollectionViewModel {
        makeSocialMyCollectionViewModel(for: UserModel(from: user))
    }

    func makeSocialMyCollectionViewModel(for user: UserModel) -> SocialMyCollectionViewModel {
        SocialMyCollectionViewModel(
            initialUser: user,
            userService: userService,
            diaryService: diaryService,
            subscribeService: subscribeService,
            onToggleMyPick: { [self] userId, isCurrentlyMyPick in
                try await onToggleMyPick(userId, isCurrentlyMyPick)
            }
        )
    }

    func formattedUpdateDate(from rawUpdateDate: String) -> String {
        let datePart = rawUpdateDate.split(separator: "T").first.map(String.init) ?? rawUpdateDate
        return datePart.replacingOccurrences(of: "-", with: ".")
    }

    private func appendFeeds(with newFeeds: [DiaryFeedModel]) {
        let existingIDs = Set(feeds.map(\.id))
        let filtered = newFeeds.filter { !existingIDs.contains($0.id) }
        feeds.append(contentsOf: filtered)
    }

    private func appendConnectionUsers(with newUsers: [SubscribeUserModel]) {
        let existingIDs = Set(connectionUsers.map(\.userId))
        let filtered = newUsers.filter { !existingIDs.contains($0.userId) }
        connectionUsers.append(contentsOf: filtered)
    }

    private func updateFeedPaging(from response: UserDiaryFeedsResponse) {
        nextFeedPage = max(response.page.number, 0) + 1
        let totalPages = max(response.page.totalPages, 0)
        let hasNextByPage = nextFeedPage < totalPages
        let hasNextByCount = response.content.count >= DiaryService.defaultSize
        hasNextFeedPage = hasNextByPage || hasNextByCount
    }

    private func updateConnectionPaging(from response: SubscribeListResponse) {
        nextConnectionPage = max(response.page.number, 0) + 1
        let totalPages = max(response.page.totalPages, 0)
        let hasNextByPage = nextConnectionPage < totalPages
        let hasNextByCount = response.content.count >= SubscribeService.defaultSize
        hasNextConnectionPage = hasNextByPage || hasNextByCount
    }

    private func fetchConnections(type: ConnectionType, page: Int) async throws -> SubscribeListResponse {
        switch type {
        case .picks:
            return try await subscribeService.fetchSubscribes(
                userId: user.userId,
                page: page,
                size: SubscribeService.defaultSize
            )
        case .fandom:
            return try await subscribeService.fetchSubscribers(
                userId: user.userId,
                page: page,
                size: SubscribeService.defaultSize
            )
        }
    }

    private func resolveErrorMessage(from error: Error) -> String {
        if let userError = error as? UserServiceError {
            return userError.errorDescription ?? "회원 정보를 불러오지 못했어요."
        }

        if let diaryError = error as? DiaryServiceError {
            return diaryError.errorDescription ?? "피드 목록을 불러오지 못했어요."
        }

        if let subscribeError = error as? SubscribeServiceError {
            return subscribeError.errorDescription ?? "구독 목록을 불러오지 못했어요."
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

    enum ConnectionType {
        case picks
        case fandom
    }
}
