import Foundation

@MainActor
final class SocialViewModel: ObservableObject {
    @Published private(set) var myPickUsers: [SubscribeUserModel] = []
    @Published private(set) var myFandomUsers: [SubscribeUserModel] = []
    @Published private(set) var isLoadingMyPick = false
    @Published private(set) var isLoadingMyFandom = false
    @Published private(set) var hasLoadedInitialData = false
    @Published var errorMessage: String?

    private let userService: UserServicing
    private let subscribeService: SubscribeServicing

    init(
        userService: UserServicing = UserService(),
        subscribeService: SubscribeServicing = SubscribeService()
    ) {
        self.userService = userService
        self.subscribeService = subscribeService
    }

    func loadInitialDataIfNeeded() async {
        guard !hasLoadedInitialData else { return }
        await refresh()
    }

    func refresh() async {
        errorMessage = nil

        do {
            let myUser = try await userService.fetchMyUser()
            async let subscribers: SubscribeListResponse = loadSubscribers(userId: myUser.userId)
            async let subscribes: SubscribeListResponse = loadSubscribes(userId: myUser.userId)
            let (subscriberResponse, subscribeResponse) = try await (subscribers, subscribes)

            myPickUsers = subscribeResponse.content
            myFandomUsers = subscriberResponse.content
            hasLoadedInitialData = true
        } catch {
            if isRequestCancelled(error) { return }
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    private func loadSubscribers(userId: Int) async throws -> SubscribeListResponse {
        isLoadingMyPick = true
        defer { isLoadingMyPick = false }
        return try await subscribeService.fetchSubscribers(
            userId: userId,
            page: SubscribeService.defaultPage,
            size: SubscribeService.defaultSize
        )
    }

    private func loadSubscribes(userId: Int) async throws -> SubscribeListResponse {
        isLoadingMyFandom = true
        defer { isLoadingMyFandom = false }
        return try await subscribeService.fetchSubscribes(
            userId: userId,
            page: SubscribeService.defaultPage,
            size: SubscribeService.defaultSize
        )
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
