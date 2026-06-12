//
//  MyCollectionViewModel.swift
//  KillingPart
//
//  Created by 이병찬 on 2/15/26.
//

import Foundation

@MainActor
final class MyCollectionViewModel: ObservableObject {
    @Published private(set) var isProcessing = false
    @Published private(set) var user: UserModel?
    @Published private(set) var userStatics: UserStaticsModel?
    @Published private(set) var myFeeds: [DiaryFeedModel] = []
    @Published private(set) var isLoadingMoreFeeds = false
    @Published private(set) var connectionUsers: [SubscribeUserModel] = []
    @Published private(set) var isLoadingConnections = false
    @Published private(set) var isLoadingMoreConnections = false
    @Published private(set) var likeUsers: [UserModel] = []
    @Published private(set) var isLoadingLikeUsers = false
    @Published private(set) var isLoadingMoreLikeUsers = false
    @Published var connectionErrorMessage: String?
    @Published var likeUsersErrorMessage: String?
    @Published var errorMessage: String?

    private let authenticationService: AuthenticationServicing
    private let userService: UserServicing
    private let diaryService: DiaryServicing
    private let subscribeService: SubscribeServicing

    private var hasLoadedProfile = false
    private var hasLoadedUserStatics = false
    private var hasLoadedMyFeeds = false
    private var isLoadingProfile = false
    private var isLoadingUserStatics = false
    private var isLoadingMyFeeds = false
    private let defaultFeedPageSize = DiaryService.defaultSize
    private var nextFeedPage = 0
    private var hasNextFeedPage = true
    private var hasPendingBottomPaginationRequest = false
    private var hasPendingFocusRefetchRequest = false
    private var activeConnectionType: ConnectionType?
    private var nextConnectionPage = SubscribeService.defaultPage
    private var hasNextConnectionPage = true
    private var connectionRequestID = 0
    private let likeUsersPageSize = 20
    private var activeLikeUsersDiaryId: Int?
    private var activeLikeUsersSearchCond: String?
    private var likeUsersNextPage = DiaryService.defaultPage
    private var hasNextLikeUsersPage = true
    private var likeUsersRequestID = 0

    init(
        authenticationService: AuthenticationServicing,
        userService: UserServicing = UserService(),
        diaryService: DiaryServicing = DiaryService(),
        subscribeService: SubscribeServicing = SubscribeService()
    ) {
        self.authenticationService = authenticationService
        self.userService = userService
        self.diaryService = diaryService
        self.subscribeService = subscribeService
    }

    var displayName: String {
        let username = user?.username.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return username.isEmpty ? "킬링파트 사용자" : username
    }

    var displayTag: String {
        let tag = user?.tag.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !tag.isEmpty else { return "@killingpart_user" }
        return tag.hasPrefix("@") ? tag : "@\(tag)"
    }

    var profileImageURL: URL? {
        user?.profileImageURL
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

    func makeSocialMyCollectionViewModel(for user: UserModel) -> SocialMyCollectionViewModel {
        SocialMyCollectionViewModel(
            initialUser: user,
            userService: userService,
            diaryService: diaryService,
            subscribeService: subscribeService,
            onToggleMyPick: { [self] userId, isCurrentlyMyPick in
                try await toggleMyPick(for: userId, isCurrentlyMyPick: isCurrentlyMyPick)
            }
        )
    }

    func makeSocialMyCollectionViewModel(for user: SubscribeUserModel) -> SocialMyCollectionViewModel {
        makeSocialMyCollectionViewModel(for: UserModel(from: user))
    }

    func loadConnections(type: ConnectionType) async {
        if user == nil {
            await loadMyProfileIfNeeded()
        }
        guard let myUserID = user?.userId else { return }

        connectionRequestID += 1
        let requestID = connectionRequestID
        activeConnectionType = type
        nextConnectionPage = SubscribeService.defaultPage
        hasNextConnectionPage = true
        connectionUsers = []
        connectionErrorMessage = nil
        isLoadingConnections = true
        defer {
            if connectionRequestID == requestID {
                isLoadingConnections = false
            }
        }

        do {
            let response = try await fetchConnections(
                userId: myUserID,
                type: type,
                page: SubscribeService.defaultPage
            )
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

        if user == nil {
            await loadMyProfileIfNeeded()
        }
        guard let myUserID = user?.userId else { return }

        isLoadingMoreConnections = true
        defer { isLoadingMoreConnections = false }

        do {
            let response = try await fetchConnections(
                userId: myUserID,
                type: activeConnectionType,
                page: nextConnectionPage
            )
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

    func loadInitialDataIfNeeded() async {
        async let profileLoad: Void = loadMyProfileIfNeeded()
        async let feedLoad: Void = loadMyFeedsIfNeeded()
        _ = await (profileLoad, feedLoad)
    }

    func refetchCollectionDataOnFocus() async {
        guard !isLoadingProfile, !isLoadingUserStatics, !isLoadingMyFeeds else {
            hasPendingFocusRefetchRequest = true
            return
        }

        hasPendingFocusRefetchRequest = false
        hasPendingBottomPaginationRequest = false
        hasLoadedProfile = false
        hasLoadedUserStatics = false

        async let profileLoad: Void = loadMyProfile()
        async let feedLoad: Void = refreshCollectionData()
        _ = await (profileLoad, feedLoad)
    }

    func loadMyProfileIfNeeded() async {
        guard !hasLoadedProfile else { return }
        await loadMyProfile()
    }

    func loadMyFeedsIfNeeded() async {
        guard !hasLoadedMyFeeds else { return }
        await loadMyFeeds(
            page: DiaryService.defaultPage,
            size: defaultFeedPageSize,
            mode: .initial
        )
    }

    func loadMoreMyFeedsFromBottomIfNeeded() async {
        guard hasLoadedMyFeeds else { return }
        guard hasNextFeedPage else { return }
        guard !isLoadingMyFeeds else {
            hasPendingBottomPaginationRequest = true
            return
        }

        await loadMyFeeds(page: nextFeedPage, size: defaultFeedPageSize, mode: .pagination)
    }

    func refreshCollectionData() async {
        hasLoadedMyFeeds = false
        nextFeedPage = DiaryService.defaultPage
        hasNextFeedPage = true
        hasPendingBottomPaginationRequest = false
        errorMessage = nil

        await loadMyFeeds(
            page: DiaryService.defaultPage,
            size: defaultFeedPageSize,
            mode: .initial
        )
    }

    func preloadPlaybackFeeds() async {
        await refetchCollectionDataOnFocus()

        var previousFeedCount = -1
        var iteration = 0
        while previousFeedCount != myFeeds.count && iteration < 200 {
            if Task.isCancelled { return }
            previousFeedCount = myFeeds.count
            await loadMoreMyFeedsFromBottomIfNeeded()
            iteration += 1
        }
    }

    func formattedUpdateDate(from rawUpdateDate: String) -> String {
        let datePart = rawUpdateDate.split(separator: "T").first.map(String.init) ?? rawUpdateDate
        return datePart.replacingOccurrences(of: "-", with: ".")
    }

    func removeMyFeedLocally(diaryId: Int) {
        myFeeds.removeAll { $0.diaryId == diaryId }
    }

    func applyUpdatedFeed(_ updatedFeed: DiaryFeedModel) {
        guard let index = myFeeds.firstIndex(where: { $0.diaryId == updatedFeed.diaryId }) else { return }
        myFeeds[index] = normalizeFeedVideoURLs(in: [updatedFeed])[0]
    }

    func applyUpdatedUser(_ updatedUser: UserModel) {
        user = updatedUser
        hasLoadedProfile = true
    }

    func logout(onSuccess: @escaping () -> Void) {
        guard !isProcessing else { return }

        isProcessing = true
        errorMessage = nil

        Task {
            defer { isProcessing = false }

            do {
                try await authenticationService.logout()
                onSuccess()
            } catch {
                errorMessage = resolveErrorMessage(from: error)
            }
        }
    }

    func deleteMyAccount(onSuccess: @escaping () -> Void) {
        guard !isProcessing else { return }

        isProcessing = true
        errorMessage = nil

        Task {
            defer { isProcessing = false }

            do {
                try await authenticationService.deleteMyAccount()
                onSuccess()
            } catch {
                errorMessage = resolveErrorMessage(from: error)
            }
        }
    }

    private func loadMyProfile() async {
        guard !isLoadingProfile else { return }

        isLoadingProfile = true
        errorMessage = nil

        defer {
            isLoadingProfile = false
            triggerPendingFocusRefetchIfNeeded()
        }

        do {
            let fetchedUser = try await userService.fetchMyUser()
            user = fetchedUser
            hasLoadedProfile = true

            await loadUserStaticsIfNeeded(userId: fetchedUser.userId)
        } catch {
            if isRequestCancelled(error) { return }
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    private func loadUserStaticsIfNeeded(userId: Int) async {
        guard !hasLoadedUserStatics else { return }
        guard !isLoadingUserStatics else { return }

        isLoadingUserStatics = true
        defer {
            isLoadingUserStatics = false
            triggerPendingFocusRefetchIfNeeded()
        }

        do {
            userStatics = try await userService.fetchUserStatics(userId: userId)
            hasLoadedUserStatics = true
        } catch {
            if isRequestCancelled(error) { return }
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    private func loadMyFeeds(page: Int, size: Int, mode: FeedLoadMode) async {
        guard !isLoadingMyFeeds else { return }

        isLoadingMyFeeds = true
        if mode == .initial {
            errorMessage = nil
        } else {
            isLoadingMoreFeeds = true
        }

        defer {
            isLoadingMyFeeds = false
            if mode == .pagination {
                isLoadingMoreFeeds = false
            }
            triggerPendingFocusRefetchIfNeeded()
            triggerPendingBottomPaginationIfNeeded()
        }

        do {
            let response = try await diaryService.fetchMyDiaries(page: page, size: size)
            let normalizedFeeds = normalizeFeedVideoURLs(in: response.content)
            if mode == .initial {
                myFeeds = normalizedFeeds
            } else {
                let existingFeedIDs = Set(myFeeds.map(\.id))
                let newFeeds = normalizedFeeds.filter { !existingFeedIDs.contains($0.id) }
                myFeeds.append(contentsOf: newFeeds)
                if newFeeds.isEmpty {
                    hasLoadedMyFeeds = true
                    hasNextFeedPage = false
                    return
                }
            }

            hasLoadedMyFeeds = true
            let totalPages = max(response.page.totalPages, 0)
            let fetchedPage = max(response.page.number, 0)
            nextFeedPage = fetchedPage + 1
            let hasNextByPage = nextFeedPage < totalPages
            let hasNextByCount = response.content.count >= size
            hasNextFeedPage = hasNextByPage || hasNextByCount
        } catch {
            if isRequestCancelled(error) { return }
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    private func toggleMyPick(for userId: Int, isCurrentlyMyPick: Bool) async throws {
        if isCurrentlyMyPick {
            try await subscribeService.unsubscribe(from: userId)
        } else {
            try await subscribeService.subscribe(to: userId)
        }
        await refetchCollectionDataOnFocus()
    }

    private func fetchConnections(
        userId: Int,
        type: ConnectionType,
        page: Int
    ) async throws -> SubscribeListResponse {
        switch type {
        case .picks:
            return try await subscribeService.fetchSubscribes(
                userId: userId,
                page: page,
                size: SubscribeService.defaultSize
            )
        case .fandom:
            return try await subscribeService.fetchSubscribers(
                userId: userId,
                page: page,
                size: SubscribeService.defaultSize
            )
        }
    }

    private func appendConnectionUsers(with newUsers: [SubscribeUserModel]) {
        let existingIDs = Set(connectionUsers.map(\.userId))
        let filtered = newUsers.filter { !existingIDs.contains($0.userId) }
        connectionUsers.append(contentsOf: filtered)
    }

    private func updateConnectionPaging(from response: SubscribeListResponse) {
        nextConnectionPage = max(response.page.number, 0) + 1
        let totalPages = max(response.page.totalPages, 0)
        let hasNextByPage = nextConnectionPage < totalPages
        let hasNextByCount = response.content.count >= SubscribeService.defaultSize
        hasNextConnectionPage = hasNextByPage || hasNextByCount
    }

    private func appendLikeUsers(with newUsers: [UserModel]) {
        let existingIDs = Set(likeUsers.map(\.userId))
        let filtered = newUsers.filter { !existingIDs.contains($0.userId) }
        likeUsers.append(contentsOf: filtered)
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

    private func normalizeFeedVideoURLs(in feeds: [DiaryFeedModel]) -> [DiaryFeedModel] {
        feeds.map { feed in
            let normalizedVideoURL = resolvedVideoURLForPlayback(from: feed.videoUrl)
            guard normalizedVideoURL != feed.videoUrl else { return feed }
            return feed.replacingVideoURL(normalizedVideoURL)
        }
    }

    private func resolvedVideoURLForPlayback(from rawVideoURL: String) -> String {
        let trimmedVideoURL = rawVideoURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedVideoURL.isEmpty else { return rawVideoURL }
        guard isLikelyYouTubeVideoID(trimmedVideoURL) else { return trimmedVideoURL }
        return "https://www.youtube.com/embed/\(trimmedVideoURL)?playsinline=1"
    }

    private func isLikelyYouTubeVideoID(_ value: String) -> Bool {
        if value.hasPrefix("//") {
            return false
        }

        if let components = URLComponents(string: value),
           components.scheme != nil || components.host != nil {
            return false
        }

        return !value.contains("/")
            && !value.contains("?")
            && !value.contains("&")
            && !value.contains("=")
            && !value.contains(".")
    }

    enum ConnectionType {
        case picks
        case fandom
    }

    private enum FeedLoadMode {
        case initial
        case pagination
    }

    private func resolveErrorMessage(from error: Error) -> String {
        if let subscribeError = error as? SubscribeServiceError {
            return subscribeError.errorDescription ?? "요청 처리에 실패했어요."
        }

        if let diaryServiceError = error as? DiaryServiceError {
            return diaryServiceError.errorDescription ?? "요청 처리에 실패했어요."
        }

        if let userServiceError = error as? UserServiceError {
            return userServiceError.errorDescription ?? "요청 처리에 실패했어요."
        }

        if let authError = error as? AuthenticationServiceError {
            return authError.errorDescription ?? "요청 처리에 실패했어요."
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

    private func triggerPendingBottomPaginationIfNeeded() {
        guard hasPendingBottomPaginationRequest else { return }
        guard !hasPendingFocusRefetchRequest else { return }
        hasPendingBottomPaginationRequest = false
        guard hasLoadedMyFeeds else { return }
        guard hasNextFeedPage else { return }
        guard !isLoadingMyFeeds else { return }

        Task {
            await loadMoreMyFeedsFromBottomIfNeeded()
        }
    }

    private func triggerPendingFocusRefetchIfNeeded() {
        guard hasPendingFocusRefetchRequest else { return }
        guard !isLoadingProfile else { return }
        guard !isLoadingUserStatics else { return }
        guard !isLoadingMyFeeds else { return }

        hasPendingFocusRefetchRequest = false
        Task {
            await refetchCollectionDataOnFocus()
        }
    }
}

private extension DiaryFeedModel {
    func replacingVideoURL(_ newVideoURL: String) -> DiaryFeedModel {
        DiaryFeedModel(
            diaryId: diaryId,
            artist: artist,
            musicTitle: musicTitle,
            albumImageUrl: albumImageUrl,
            content: content,
            videoUrl: newVideoURL,
            scope: scope,
            duration: duration,
            totalDuration: totalDuration,
            start: start,
            end: end,
            createDate: createDate,
            updateDate: updateDate,
            isLiked: isLiked,
            isStored: isStored,
            likeCount: likeCount,
            userId: userId,
            username: username,
            tag: tag,
            profileImageUrl: profileImageUrl,
            isMyPick: isMyPick
        )
    }
}
