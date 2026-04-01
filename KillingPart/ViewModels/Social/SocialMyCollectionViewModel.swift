import Foundation

@MainActor
final class SocialMyCollectionViewModel: ObservableObject {
    @Published private(set) var user: UserModel
    @Published private(set) var userStatics: UserStaticsModel?
    @Published private(set) var feeds: [DiaryFeedModel]
    @Published private(set) var isLoadingInitial = false
    @Published private(set) var isLoadingMoreFeeds = false
    @Published var errorMessage: String?

    private let userService: UserServicing
    private let diaryService: DiaryServicing

    private var hasLoadedInitialData = false
    private var nextFeedPage: Int
    private var hasNextFeedPage: Bool

    init(
        initialUser: UserModel,
        initialUserStatics: UserStaticsModel? = nil,
        initialFeeds: [DiaryFeedModel] = [],
        initialNextFeedPage: Int = DiaryService.defaultPage,
        initialHasNextFeedPage: Bool = true,
        userService: UserServicing = UserService(),
        diaryService: DiaryServicing = DiaryService()
    ) {
        user = initialUser
        userStatics = initialUserStatics
        feeds = initialFeeds
        nextFeedPage = initialNextFeedPage
        hasNextFeedPage = initialHasNextFeedPage
        self.userService = userService
        self.diaryService = diaryService
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

    func formattedUpdateDate(from rawUpdateDate: String) -> String {
        let datePart = rawUpdateDate.split(separator: "T").first.map(String.init) ?? rawUpdateDate
        return datePart.replacingOccurrences(of: "-", with: ".")
    }

    private func appendFeeds(with newFeeds: [DiaryFeedModel]) {
        let existingIDs = Set(feeds.map(\.id))
        let filtered = newFeeds.filter { !existingIDs.contains($0.id) }
        feeds.append(contentsOf: filtered)
    }

    private func updateFeedPaging(from response: UserDiaryFeedsResponse) {
        nextFeedPage = max(response.page.number, 0) + 1
        let totalPages = max(response.page.totalPages, 0)
        let hasNextByPage = nextFeedPage < totalPages
        let hasNextByCount = response.content.count >= DiaryService.defaultSize
        hasNextFeedPage = hasNextByPage || hasNextByCount
    }

    private func resolveErrorMessage(from error: Error) -> String {
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
