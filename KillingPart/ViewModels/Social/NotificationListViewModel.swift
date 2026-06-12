import Foundation

struct AlarmMyDiaryDestination {
    let diary: DiaryFeedModel
    let displayTag: String
}

struct AlarmSocialDiaryDestination {
    let diary: DiaryFeedModel
    let displayTag: String
    let user: UserModel
}

struct AlarmSocialCollectionDestination {
    let user: UserModel
    let initialUserFeedsResponse: UserDiaryFeedsResponse?
}

enum NotificationListExternalRoute: Equatable {
    case socialFriends
}

@MainActor
final class NotificationListViewModel: ObservableObject {
    @Published private(set) var alarms: [AlarmHistoryItem] = []
    @Published private(set) var isLoadingAlarms = false
    @Published private(set) var isLoadingMoreAlarms = false
    @Published private(set) var alarmsErrorMessage: String?
    @Published private(set) var hasUnreadAlarms = false
    @Published private(set) var selectedAlarmIDs: Set<Int> = []
    @Published var isAlarmSelectionMode = false
    @Published private(set) var activeMyDiaryDestination: AlarmMyDiaryDestination?
    @Published private(set) var activeSocialDiaryDestination: AlarmSocialDiaryDestination?
    @Published private(set) var activeSocialCollectionDestination: AlarmSocialCollectionDestination?
    @Published private(set) var isSubscribeFansSheetPresented = false
    @Published private(set) var subscribeFans: [SubscribeUserModel] = []
    @Published private(set) var isLoadingSubscribeFans = false
    @Published private(set) var isLoadingMoreSubscribeFans = false
    @Published private(set) var subscribeFansErrorMessage: String?
    @Published private(set) var pendingExternalRoute: NotificationListExternalRoute?
    @Published private(set) var routingErrorMessage: String?
    @Published private(set) var isDeletingAlarms = false

    private let userService: UserServicing
    private let diaryService: DiaryServicing
    private let subscribeService: SubscribeServicing
    private let notificationService: NotificationServicing
    private let userDefaults: UserDefaults

    private var myUserID: Int?
    private var hasLoadedInitialAlarms = false
    private var alarmsNextPage = 0
    private var hasNextAlarmsPage = true
    private var subscribeFansUserID: Int?
    private var subscribeFansNextPage = SubscribeService.defaultPage
    private var hasNextSubscribeFansPage = true
    private var readAlarmIDs: Set<Int> = []
    private var deletedAlarmIDs: Set<Int> = []
    private var deletedAlarmsBeforeDate: Date?
    private var isAlarmListActive = false
    private let alarmPageSize = 20
    private let subscribeFansPageSize = 20
    private let alarmReadIDStorageKeyPrefix = "social.readAlarmIDs.user"
    private let alarmDeletedIDStorageKeyPrefix = "social.deletedAlarmIDs.user"
    private let alarmDeletedBeforeStorageKeyPrefix = "social.deletedAlarmsBefore.user"

    init(
        userService: UserServicing = UserService(),
        diaryService: DiaryServicing = DiaryService(),
        subscribeService: SubscribeServicing = SubscribeService(),
        notificationService: NotificationServicing = NotificationService(),
        userDefaults: UserDefaults = .standard
    ) {
        self.userService = userService
        self.diaryService = diaryService
        self.subscribeService = subscribeService
        self.notificationService = notificationService
        self.userDefaults = userDefaults
    }

    func enterList() async {
        isAlarmListActive = true
        if hasLoadedInitialAlarms {
            markLoadedAlarmsAsRead()
            return
        }

        await refreshAlarms()
    }

    func exitList() {
        isAlarmListActive = false
        setAlarmSelectionMode(false)
    }

    func refreshAlarms() async {
        guard !isLoadingAlarms else { return }
        isLoadingAlarms = true
        defer { isLoadingAlarms = false }

        alarmsErrorMessage = nil
        routingErrorMessage = nil
        resetAlarmPagingState()

        do {
            try await ensureMyUserID()
            loadReadAlarmIDsFromStorage()
            loadDeletedAlarmStateFromStorage()

            let response = try await notificationService.fetchAlarmHistory(
                page: 0,
                size: alarmPageSize
            )
            alarms = visibleAlarms(from: response.content)
            updateAlarmsPaging(from: response)
            hasLoadedInitialAlarms = true
            if isAlarmListActive {
                markLoadedAlarmsAsRead()
            } else {
                updateUnreadAlarmIndicator()
            }
        } catch {
            if isRequestCancelled(error) { return }
            alarmsErrorMessage = resolveErrorMessage(from: error)
        }
    }

    func loadAlarmHistoryIfNeeded() async {
        guard !hasLoadedInitialAlarms else { return }
        await refreshAlarms()
    }

    func loadMoreAlarmHistoryIfNeeded(currentAlarmId: Int) async {
        guard alarms.last?.alarmId == currentAlarmId else { return }
        guard hasNextAlarmsPage else { return }
        guard !isLoadingAlarms, !isLoadingMoreAlarms else { return }

        isLoadingMoreAlarms = true
        defer { isLoadingMoreAlarms = false }

        do {
            let response = try await notificationService.fetchAlarmHistory(
                page: alarmsNextPage,
                size: alarmPageSize
            )
            appendAlarms(with: response.content)
            updateAlarmsPaging(from: response)
            if isAlarmListActive {
                markLoadedAlarmsAsRead()
            } else {
                updateUnreadAlarmIndicator()
            }
        } catch {
            if isRequestCancelled(error) { return }
            alarmsErrorMessage = resolveErrorMessage(from: error)
        }
    }

    func isAlarmRead(_ alarmId: Int) -> Bool {
        readAlarmIDs.contains(alarmId)
    }

    func markAlarmAsRead(_ alarmId: Int) {
        guard !readAlarmIDs.contains(alarmId) else { return }
        readAlarmIDs.insert(alarmId)
        persistReadAlarmIDs()
        updateUnreadAlarmIndicator()
    }

    func setAlarmSelectionMode(_ isEnabled: Bool) {
        isAlarmSelectionMode = isEnabled
        if !isEnabled {
            selectedAlarmIDs.removeAll()
        }
    }

    func toggleAlarmSelection(_ alarmId: Int) {
        if selectedAlarmIDs.contains(alarmId) {
            selectedAlarmIDs.remove(alarmId)
        } else {
            selectedAlarmIDs.insert(alarmId)
        }
    }

    func toggleSelectAllAlarms() {
        let allIDs = Set(alarms.map(\.alarmId))
        if allIDs.isEmpty {
            selectedAlarmIDs.removeAll()
            return
        }

        if selectedAlarmIDs.count == allIDs.count {
            selectedAlarmIDs.removeAll()
        } else {
            selectedAlarmIDs = allIDs
        }
    }

    func deleteSelectedAlarms() {
        guard !selectedAlarmIDs.isEmpty else { return }
        isDeletingAlarms = true
        defer { isDeletingAlarms = false }

        readAlarmIDs.formUnion(selectedAlarmIDs)
        deletedAlarmIDs.formUnion(selectedAlarmIDs)
        alarms.removeAll { selectedAlarmIDs.contains($0.alarmId) }
        persistReadAlarmIDs()
        persistDeletedAlarmState()
        updateUnreadAlarmIndicator()
        selectedAlarmIDs.removeAll()
        isAlarmSelectionMode = false
    }

    func deleteAllAlarms() {
        let allIDs = Set(alarms.map(\.alarmId))
        guard !allIDs.isEmpty else { return }
        isDeletingAlarms = true
        defer { isDeletingAlarms = false }

        readAlarmIDs.formUnion(allIDs)
        deletedAlarmIDs.formUnion(allIDs)
        deletedAlarmsBeforeDate = Date()
        alarms = []
        persistReadAlarmIDs()
        persistDeletedAlarmState()
        updateUnreadAlarmIndicator()
        selectedAlarmIDs.removeAll()
        isAlarmSelectionMode = false
    }

    func dismissSubscribeFansSheet() {
        isSubscribeFansSheetPresented = false
        clearSubscribeFansState()
    }

    func refreshSubscribeFans() async {
        guard let subscribeFansUserID else { return }
        let requestUserID = subscribeFansUserID
        guard !isLoadingSubscribeFans else { return }

        isLoadingSubscribeFans = true
        defer { isLoadingSubscribeFans = false }

        subscribeFansErrorMessage = nil
        resetSubscribeFansPagingState()

        do {
            let response = try await subscribeService.fetchSubscribers(
                userId: requestUserID,
                page: SubscribeService.defaultPage,
                size: subscribeFansPageSize
            )
            guard requestUserID == subscribeFansUserID else { return }
            subscribeFans = response.content
            updateSubscribeFansPaging(from: response)
        } catch {
            if isRequestCancelled(error) { return }
            guard requestUserID == subscribeFansUserID else { return }
            subscribeFansErrorMessage = resolveErrorMessage(from: error)
        }
    }

    func loadMoreSubscribeFansIfNeeded(currentUserId: Int) async {
        guard subscribeFans.last?.userId == currentUserId else { return }
        guard let subscribeFansUserID else { return }
        let requestUserID = subscribeFansUserID
        guard hasNextSubscribeFansPage else { return }
        guard !isLoadingSubscribeFans, !isLoadingMoreSubscribeFans else { return }

        isLoadingMoreSubscribeFans = true
        defer { isLoadingMoreSubscribeFans = false }

        do {
            let response = try await subscribeService.fetchSubscribers(
                userId: requestUserID,
                page: subscribeFansNextPage,
                size: subscribeFansPageSize
            )
            guard requestUserID == subscribeFansUserID else { return }
            appendSubscribeFans(with: response.content)
            updateSubscribeFansPaging(from: response)
        } catch {
            if isRequestCancelled(error) { return }
            guard requestUserID == subscribeFansUserID else { return }
            subscribeFansErrorMessage = resolveErrorMessage(from: error)
        }
    }

    func handleAlarmTap(_ alarm: AlarmHistoryItem) async {
        guard !isAlarmSelectionMode else { return }
        routingErrorMessage = nil
        pendingExternalRoute = nil
        print(
            "[NotificationRoute] tap alarmId=\(alarm.alarmId) type=\(alarm.type.rawValue) deepLink=\(alarm.deepLink)"
        )

        await executeRoute(
            type: alarm.type,
            deepLink: alarm.deepLink,
            alarmId: alarm.alarmId,
            source: "list",
            shouldMarkAsRead: true
        )
    }

    func handlePushAlarmRoute(_ route: PushAlarmRoute) async {
        routingErrorMessage = nil
        pendingExternalRoute = nil
        print(
            "[NotificationRoute][Push] tap type=\(route.type.rawValue) deepLink=\(route.deepLink) alarmId=\(route.alarmId?.description ?? "nil")"
        )

        await executeRoute(
            type: route.type,
            deepLink: route.deepLink,
            alarmId: route.alarmId,
            source: "push",
            shouldMarkAsRead: route.alarmId != nil
        )
    }

    private func executeRoute(
        type: AlarmType,
        deepLink: String,
        alarmId: Int?,
        source: String,
        shouldMarkAsRead: Bool
    ) async {
        do {
            switch type {
            case .like:
                let diaryId = try resolveDiaryID(from: deepLink)
                let diary = try await diaryService.fetchDiary(diaryId: diaryId)
                print("[NotificationRoute] LIKE_ALARM diaryId=\(diaryId) -> MyCollectionDiary")
                clearNavigationDestinations()
                activeMyDiaryDestination = AlarmMyDiaryDestination(
                    diary: diary,
                    displayTag: resolvedDisplayTag(from: diary.tag)
                )
            case .subscribe:
                let subscribedUserID = try resolveSubscribedUserID(from: deepLink)
                clearNavigationDestinations()
                if source == "list" {
                    print(
                        "[NotificationRoute] SUBSCRIBE_ALARM subscribedId=\(subscribedUserID) -> Subscribe Fans Sheet"
                    )
                    await presentSubscribeFansSheet(for: subscribedUserID)
                } else {
                    print(
                        "[NotificationRoute] SUBSCRIBE_ALARM subscribedId=\(subscribedUserID) -> Social Friends Section"
                    )
                    pendingExternalRoute = .socialFriends
                }
            case .diary:
                if let diaryId = resolveDiaryIDIfPresent(from: deepLink) {
                    let diary = try await diaryService.fetchDiary(diaryId: diaryId)
                    guard diary.userId > 0 else { throw NotificationRoutingError.missingUserID }
                    print(
                        "[NotificationRoute] DIARY_ALARM diaryId=\(diaryId) userId=\(diary.userId) -> SocialMyCollectionDiary"
                    )
                    clearNavigationDestinations()
                    activeSocialDiaryDestination = AlarmSocialDiaryDestination(
                        diary: diary,
                        displayTag: resolvedDisplayTag(from: diary.tag),
                        user: makeUser(from: diary)
                    )
                } else if let subscribedUserID = resolveSubscribedUserIDIfPresent(from: deepLink) {
                    // Fallback for mixed payloads.
                    print(
                        "[NotificationRoute] DIARY_ALARM fallback subscribedId=\(subscribedUserID) -> SocialMyCollectionView"
                    )
                    clearNavigationDestinations()
                    activeSocialCollectionDestination = AlarmSocialCollectionDestination(
                        user: makePlaceholderUser(userId: subscribedUserID),
                        initialUserFeedsResponse: nil
                    )
                } else {
                    throw NotificationRoutingError.invalidDeepLink
                }
            default:
                throw NotificationRoutingError.unsupportedType
            }

            if shouldMarkAsRead, let alarmId, alarmId > 0 {
                markAlarmAsRead(alarmId)
                print("[NotificationRoute] success source=\(source) alarmId=\(alarmId) markedAsRead=true")
            } else {
                print("[NotificationRoute] success source=\(source) alarmId=nil")
            }
        } catch {
            if isRequestCancelled(error) { return }
            print(
                "[NotificationRoute] failed source=\(source) alarmId=\(alarmId?.description ?? "nil") type=\(type.rawValue) error=\(error.localizedDescription)"
            )
            routingErrorMessage = resolveRoutingErrorMessage(from: error)
        }
    }

    func clearRoutingError() {
        routingErrorMessage = nil
    }

    func clearActiveMyDiaryDestination() {
        activeMyDiaryDestination = nil
    }

    func clearActiveSocialDiaryDestination() {
        activeSocialDiaryDestination = nil
    }

    func clearActiveSocialCollectionDestination() {
        activeSocialCollectionDestination = nil
    }

    func clearPendingExternalRoute() {
        pendingExternalRoute = nil
    }

    func routeToSubscribeFan(_ user: SubscribeUserModel) {
        dismissSubscribeFansSheet()
        clearNavigationDestinations()
        activeSocialCollectionDestination = AlarmSocialCollectionDestination(
            user: UserModel(from: user),
            initialUserFeedsResponse: nil
        )
    }

    private func presentSubscribeFansSheet(for subscribedUserID: Int) async {
        subscribeFansUserID = subscribedUserID
        isSubscribeFansSheetPresented = true
        await refreshSubscribeFans()
    }

    func makeSocialMyCollectionViewModel(
        for user: UserModel,
        initialUserFeedsResponse: UserDiaryFeedsResponse? = nil
    ) -> SocialMyCollectionViewModel {
        let initialFeeds = initialUserFeedsResponse?.content.map { $0.toDiaryFeedModel(user: user) } ?? []
        let initialNextFeedPage: Int
        let initialHasNextFeedPage: Bool

        if let response = initialUserFeedsResponse {
            initialNextFeedPage = max(response.page.number, 0) + 1
            let totalPages = max(response.page.totalPages, 0)
            let hasNextByPage = initialNextFeedPage < totalPages
            let hasNextByCount = response.content.count >= DiaryService.defaultSize
            initialHasNextFeedPage = hasNextByPage || hasNextByCount
        } else {
            initialNextFeedPage = DiaryService.defaultPage
            initialHasNextFeedPage = true
        }

        return SocialMyCollectionViewModel(
            initialUser: user,
            initialFeeds: initialFeeds,
            initialNextFeedPage: initialNextFeedPage,
            initialHasNextFeedPage: initialHasNextFeedPage,
            userService: userService,
            diaryService: diaryService,
            subscribeService: subscribeService,
            onToggleMyPick: { [self] userId, isCurrentlyMyPick in
                try await toggleMyPick(for: userId, isCurrentlyMyPick: isCurrentlyMyPick)
            }
        )
    }

    private func toggleMyPick(for userId: Int, isCurrentlyMyPick: Bool) async throws {
        if isCurrentlyMyPick {
            try await subscribeService.unsubscribe(from: userId)
        } else {
            try await subscribeService.subscribe(to: userId)
        }
    }

    private func makeUser(from diary: DiaryFeedModel) -> UserModel {
        UserModel(
            userId: diary.userId,
            username: diary.username ?? "",
            tag: diary.tag ?? "",
            identifier: "",
            profileImageUrl: diary.profileImageUrl ?? "",
            userRoleType: "",
            socialType: "",
            isMyPick: nil
        )
    }

    private func makePlaceholderUser(userId: Int) -> UserModel {
        UserModel(
            userId: userId,
            username: "",
            tag: "",
            identifier: "",
            profileImageUrl: "",
            userRoleType: "",
            socialType: "",
            isMyPick: nil
        )
    }

    private func resolveDiaryID(from deepLink: String) throws -> Int {
        guard let diaryID = extractPathParameter(
            from: deepLink,
            resourceName: "diaries"
        ) else {
            throw NotificationRoutingError.invalidDeepLink
        }
        return diaryID
    }

    private func resolveDiaryIDIfPresent(from deepLink: String) -> Int? {
        extractPathParameter(from: deepLink, resourceName: "diaries")
    }

    private func resolveSubscribedUserID(from deepLink: String) throws -> Int {
        guard let subscribedID = extractPathParameter(
            from: deepLink,
            resourceName: "subscribes"
        ) else {
            throw NotificationRoutingError.invalidDeepLink
        }
        return subscribedID
    }

    private func resolveSubscribedUserIDIfPresent(from deepLink: String) -> Int? {
        extractPathParameter(from: deepLink, resourceName: "subscribes")
    }

    private func extractPathParameter(from deepLink: String, resourceName: String) -> Int? {
        let components = deepLinkPathComponents(from: deepLink)
        guard let resourceIndex = components.firstIndex(where: { $0.caseInsensitiveCompare(resourceName) == .orderedSame }) else {
            return nil
        }

        let valueIndex = resourceIndex + 1
        guard components.indices.contains(valueIndex) else { return nil }
        return parsePositiveInt(components[valueIndex])
    }

    private func deepLinkPathComponents(from deepLink: String) -> [String] {
        let trimmed = deepLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if let components = URLComponents(string: trimmed) {
            let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !path.isEmpty {
                return path.split(separator: "/").map(String.init)
            }
        }

        return trimmed
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .split(separator: "/")
            .map(String.init)
    }

    private func parsePositiveInt(_ value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = Int(trimmed), parsed > 0 else { return nil }
        return parsed
    }

    private func resolvedDisplayTag(from tag: String?) -> String {
        let trimmed = tag?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return "@killingpart_user" }
        return trimmed.hasPrefix("@") ? trimmed : "@\(trimmed)"
    }

    private func clearNavigationDestinations() {
        activeMyDiaryDestination = nil
        activeSocialDiaryDestination = nil
        activeSocialCollectionDestination = nil
    }

    private func clearSubscribeFansState() {
        subscribeFans = []
        subscribeFansErrorMessage = nil
        subscribeFansUserID = nil
        isLoadingSubscribeFans = false
        isLoadingMoreSubscribeFans = false
        resetSubscribeFansPagingState()
    }

    private func appendSubscribeFans(with newUsers: [SubscribeUserModel]) {
        let existingIDs = Set(subscribeFans.map(\.userId))
        let filtered = newUsers.filter { !existingIDs.contains($0.userId) }
        subscribeFans.append(contentsOf: filtered)
    }

    private func updateSubscribeFansPaging(from response: SubscribeListResponse) {
        subscribeFansNextPage = max(response.page.number, 0) + 1
        let totalPages = max(response.page.totalPages, 0)
        let hasNextByPage = subscribeFansNextPage < totalPages
        let hasNextByCount = response.content.count >= subscribeFansPageSize
        hasNextSubscribeFansPage = hasNextByPage || hasNextByCount
    }

    private func resetSubscribeFansPagingState() {
        subscribeFans = []
        subscribeFansNextPage = SubscribeService.defaultPage
        hasNextSubscribeFansPage = true
    }

    private func appendAlarms(with newAlarms: [AlarmHistoryItem]) {
        let existingIDs = Set(alarms.map(\.alarmId))
        let filtered = visibleAlarms(from: newAlarms)
            .filter { !existingIDs.contains($0.alarmId) }
        alarms.append(contentsOf: filtered)
    }

    private func updateAlarmsPaging(from response: AlarmHistoryResponse) {
        alarmsNextPage = max(response.page.number, 0) + 1
        let totalPages = max(response.page.totalPages, 0)
        let hasNextByPage = alarmsNextPage < totalPages
        let hasNextByCount = response.content.count >= alarmPageSize
        hasNextAlarmsPage = hasNextByPage || hasNextByCount
    }

    private func resetAlarmPagingState() {
        alarms = []
        alarmsNextPage = 0
        hasNextAlarmsPage = true
        selectedAlarmIDs.removeAll()
        isAlarmSelectionMode = false
    }

    private func visibleAlarms(from source: [AlarmHistoryItem]) -> [AlarmHistoryItem] {
        source.filter { alarm in
            alarm.alarmId > 0 && !isAlarmDeleted(alarm)
        }
    }

    private func isAlarmDeleted(_ alarm: AlarmHistoryItem) -> Bool {
        if deletedAlarmIDs.contains(alarm.alarmId) {
            return true
        }

        guard
            let deletedAlarmsBeforeDate,
            let createdDate = NotificationAlarmDateParser.date(from: alarm.createDate ?? "")
        else {
            return false
        }

        return createdDate <= deletedAlarmsBeforeDate
    }

    private func markLoadedAlarmsAsRead() {
        let alarmIDs = Set(alarms.map(\.alarmId))
        guard !alarmIDs.isEmpty else {
            updateUnreadAlarmIndicator()
            return
        }

        readAlarmIDs.formUnion(alarmIDs)
        persistReadAlarmIDs()
        updateUnreadAlarmIndicator()
    }

    private func ensureMyUserID() async throws {
        if myUserID != nil { return }
        let myUser = try await userService.fetchMyUser()
        myUserID = myUser.userId
    }

    private func loadReadAlarmIDsFromStorage() {
        guard let key = resolvedReadAlarmIDStorageKey() else { return }

        if let storedIDs = userDefaults.array(forKey: key) as? [Int] {
            readAlarmIDs = Set(storedIDs)
            return
        }

        if let storedStrings = userDefaults.array(forKey: key) as? [String] {
            readAlarmIDs = Set(storedStrings.compactMap { Int($0) })
            return
        }

        readAlarmIDs = []
    }

    private func persistReadAlarmIDs() {
        guard let key = resolvedReadAlarmIDStorageKey() else { return }
        userDefaults.set(Array(readAlarmIDs), forKey: key)
    }

    private func loadDeletedAlarmStateFromStorage() {
        guard
            let deletedIDKey = resolvedDeletedAlarmIDStorageKey(),
            let deletedBeforeKey = resolvedDeletedAlarmsBeforeStorageKey()
        else {
            return
        }

        if let storedIDs = userDefaults.array(forKey: deletedIDKey) as? [Int] {
            deletedAlarmIDs = Set(storedIDs)
        } else if let storedStrings = userDefaults.array(forKey: deletedIDKey) as? [String] {
            deletedAlarmIDs = Set(storedStrings.compactMap { Int($0) })
        } else {
            deletedAlarmIDs = []
        }

        let storedTimestamp = userDefaults.double(forKey: deletedBeforeKey)
        deletedAlarmsBeforeDate = storedTimestamp > 0 ? Date(timeIntervalSince1970: storedTimestamp) : nil
    }

    private func persistDeletedAlarmState() {
        guard
            let deletedIDKey = resolvedDeletedAlarmIDStorageKey(),
            let deletedBeforeKey = resolvedDeletedAlarmsBeforeStorageKey()
        else {
            return
        }

        userDefaults.set(Array(deletedAlarmIDs), forKey: deletedIDKey)
        if let deletedAlarmsBeforeDate {
            userDefaults.set(deletedAlarmsBeforeDate.timeIntervalSince1970, forKey: deletedBeforeKey)
        } else {
            userDefaults.removeObject(forKey: deletedBeforeKey)
        }
    }

    private func updateUnreadAlarmIndicator() {
        hasUnreadAlarms = alarms.contains { !readAlarmIDs.contains($0.alarmId) }
    }

    private func resolvedReadAlarmIDStorageKey() -> String? {
        guard let myUserID else { return nil }
        return "\(alarmReadIDStorageKeyPrefix).\(myUserID)"
    }

    private func resolvedDeletedAlarmIDStorageKey() -> String? {
        guard let myUserID else { return nil }
        return "\(alarmDeletedIDStorageKeyPrefix).\(myUserID)"
    }

    private func resolvedDeletedAlarmsBeforeStorageKey() -> String? {
        guard let myUserID else { return nil }
        return "\(alarmDeletedBeforeStorageKeyPrefix).\(myUserID)"
    }

    private func resolveRoutingErrorMessage(from error: Error) -> String {
        if let routingError = error as? NotificationRoutingError {
            return routingError.errorDescription ?? "알림으로 이동할 수 없어요."
        }

        if let diaryError = error as? DiaryServiceError {
            return diaryError.errorDescription ?? "알림으로 이동할 수 없어요."
        }

        return resolveErrorMessage(from: error)
    }

    private func resolveErrorMessage(from error: Error) -> String {
        if let notificationError = error as? NotificationServiceError {
            return notificationError.errorDescription ?? "알림 목록을 불러오지 못했어요."
        }

        if let diaryError = error as? DiaryServiceError {
            return diaryError.errorDescription ?? "요청 처리에 실패했어요."
        }

        if let subscribeError = error as? SubscribeServiceError {
            return subscribeError.errorDescription ?? "요청 처리에 실패했어요."
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

private enum NotificationRoutingError: LocalizedError {
    case invalidDeepLink
    case missingUserID
    case unsupportedType

    var errorDescription: String? {
        switch self {
        case .invalidDeepLink:
            return "알림 이동 경로가 올바르지 않아요."
        case .missingUserID:
            return "대상 사용자를 확인할 수 없어요."
        case .unsupportedType:
            return "아직 지원하지 않는 알림 유형이에요."
        }
    }
}

private enum NotificationAlarmDateParser {
    private static let inputWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let inputWithoutFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let serverDateFormats: [String] = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd HH:mm:ss"
    ]

    static func date(from rawDate: String) -> Date? {
        let trimmed = rawDate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let date = inputWithFractionalSeconds.date(from: trimmed) {
            return date
        }

        if let date = inputWithoutFractionalSeconds.date(from: trimmed) {
            return date
        }

        for format in serverDateFormats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        return nil
    }
}
