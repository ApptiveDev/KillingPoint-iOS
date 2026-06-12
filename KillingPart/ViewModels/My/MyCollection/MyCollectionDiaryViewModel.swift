import Foundation

@MainActor
final class MyCollectionDiaryViewModel: ObservableObject {
    @Published private(set) var diary: DiaryFeedModel
    @Published var displayedStart: String
    @Published var displayedEnd: String
    @Published var displayedContent: String
    @Published var editContentDraft: String
    @Published var isEditMode = false
    @Published private(set) var isProcessing = false
    @Published private(set) var isUpdatingInteraction = false
    @Published private(set) var isDeleted = false
    @Published private(set) var likeUsers: [UserModel] = []
    @Published private(set) var isLoadingLikeUsers = false
    @Published private(set) var isLoadingMoreLikeUsers = false
    @Published var likeUsersErrorMessage: String?
    @Published var errorMessage: String?

    private let diaryService: DiaryServicing
    private var isRefreshingInteractionState = false
    private let maxRefreshScanPageCount = 100
    private let likeUsersPageSize = 20
    private var activeLikeUsersSearchCond: String?
    private var likeUsersNextPage = DiaryService.defaultPage
    private var hasNextLikeUsersPage = true
    private var likeUsersRequestID = 0

    init(
        diary: DiaryFeedModel,
        diaryService: DiaryServicing = DiaryService()
    ) {
        self.diary = diary
        self.diaryService = diaryService
        self.displayedStart = diary.start
        self.displayedEnd = diary.end
        self.displayedContent = diary.content
        self.editContentDraft = diary.content
    }

    var startSeconds: Double {
        parsedSeconds(from: displayedStart) ?? 0
    }

    var endSeconds: Double {
        let parsedEnd = parsedSeconds(from: displayedEnd) ?? startSeconds
        return max(parsedEnd, startSeconds + 0.1)
    }

    var totalSeconds: Double {
        let parsedTotal = parsedSeconds(from: diary.totalDuration) ?? 0
        return max(parsedTotal, endSeconds, 1)
    }

    var startMinuteSecondText: String {
        TimeFormatter.minuteSecondText(from: startSeconds)
    }

    var endMinuteSecondText: String {
        TimeFormatter.minuteSecondText(from: endSeconds)
    }

    var canSubmitEdit: Bool {
        !isProcessing
            && !trimmedEditContent.isEmpty
            && trimmedEditContent != trimmedDisplayedContent
    }

    func beginEdit() {
        guard !isProcessing else { return }
        editContentDraft = displayedContent
        errorMessage = nil
        isEditMode = true
    }

    func cancelEdit() {
        guard !isProcessing else { return }
        editContentDraft = displayedContent
        errorMessage = nil
        isEditMode = false
    }

    func submitEdit() async -> Bool {
        guard !isProcessing else { return false }
        guard canSubmitEdit else {
            errorMessage = "코멘트를 입력해 주세요."
            return false
        }

        let payload = trimmedEditContent
        let request = DiaryUpdateRequest(
            content: payload
        )

        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            try await diaryService.updateDiary(diaryId: diary.diaryId, request: request)
            displayedContent = payload
            diary = diary.replacingContent(payload)
            isEditMode = false
            return true
        } catch {
            if isRequestCancelled(error) { return false }
            errorMessage = resolveErrorMessage(from: error)
            return false
        }
    }

    func deleteDiary() async -> Bool {
        guard !isProcessing else { return false }

        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            try await diaryService.deleteDiary(diaryId: diary.diaryId)
            isDeleted = true
            return true
        } catch {
            if isRequestCancelled(error) { return false }
            errorMessage = resolveErrorMessage(from: error)
            return false
        }
    }

    func toggleLike() async -> Bool {
        guard !isProcessing, !isUpdatingInteraction, !isDeleted else { return false }

        let originalDiary = diary
        let toggledIsLiked = !originalDiary.isLiked
        let optimisticLikeCount = max(originalDiary.likeCount + (toggledIsLiked ? 1 : -1), 0)
        diary = originalDiary.replacingInteraction(
            isLiked: toggledIsLiked,
            likeCount: optimisticLikeCount
        )
        errorMessage = nil
        isUpdatingInteraction = true
        defer { isUpdatingInteraction = false }

        do {
            let response = try await diaryService.toggleDiaryLike(diaryId: originalDiary.diaryId)
            let currentDiary = diary
            let confirmedLikeCount = max(
                currentDiary.likeCount + (response.isLiked == currentDiary.isLiked ? 0 : (response.isLiked ? 1 : -1)),
                0
            )
            diary = currentDiary.replacingInteraction(
                isLiked: response.isLiked,
                likeCount: confirmedLikeCount
            )
            return true
        } catch {
            if isRequestCancelled(error) { return false }
            diary = originalDiary
            errorMessage = resolveErrorMessage(from: error)
            return false
        }
    }

    func toggleStore() async -> Bool {
        guard !isProcessing, !isUpdatingInteraction, !isDeleted else { return false }

        let originalDiary = diary
        let toggledIsStored = !originalDiary.isStored
        diary = originalDiary.replacingInteraction(isStored: toggledIsStored)
        errorMessage = nil
        isUpdatingInteraction = true
        defer { isUpdatingInteraction = false }

        do {
            let response = try await diaryService.toggleDiaryStore(diaryId: originalDiary.diaryId)
            diary = diary.replacingInteraction(isStored: response.isStored)
            return true
        } catch {
            if isRequestCancelled(error) { return false }
            diary = originalDiary
            errorMessage = resolveErrorMessage(from: error)
            return false
        }
    }

    func refreshInteractionStateIfNeeded(preferredUserId: Int? = nil) async {
        guard !isDeleted, !isProcessing, !isUpdatingInteraction else { return }
        guard !isRefreshingInteractionState else { return }

        isRefreshingInteractionState = true
        defer { isRefreshingInteractionState = false }

        do {
            guard let latestInteraction = try await fetchLatestInteractionState(preferredUserId: preferredUserId) else {
                return
            }
            diary = diary.replacingInteraction(
                isLiked: latestInteraction.isLiked,
                isStored: latestInteraction.isStored,
                likeCount: latestInteraction.likeCount
            )
        } catch {
            if isRequestCancelled(error) { return }
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    func loadLikeUsers(searchCond: String? = nil) async {
        likeUsersRequestID += 1
        let requestID = likeUsersRequestID
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
                diaryId: diary.diaryId,
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

        isLoadingMoreLikeUsers = true
        defer { isLoadingMoreLikeUsers = false }

        do {
            let response = try await diaryService.fetchDiaryLikeUsers(
                diaryId: diary.diaryId,
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
        await loadLikeUsers(searchCond: activeLikeUsersSearchCond)
    }

    func clearLikeUsersState() {
        likeUsersRequestID += 1
        activeLikeUsersSearchCond = nil
        likeUsers = []
        likeUsersErrorMessage = nil
        likeUsersNextPage = DiaryService.defaultPage
        hasNextLikeUsersPage = true
        isLoadingLikeUsers = false
        isLoadingMoreLikeUsers = false
    }

    private var trimmedEditContent: String {
        editContentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDisplayedContent: String {
        displayedContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parsedSeconds(from value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let raw = Double(trimmed) {
            return max(raw, 0)
        }

        let sanitized = trimmed.replacingOccurrences(of: "초", with: "")
        if sanitized.contains(":") {
            let parts = sanitized.split(separator: ":").map(String.init)
            guard
                parts.count == 2,
                let minutes = Double(parts[0]),
                let seconds = Double(parts[1])
            else {
                return nil
            }
            return max((minutes * 60) + seconds, 0)
        }

        if let raw = Double(sanitized) {
            return max(raw, 0)
        }

        return nil
    }

    private func fetchLatestInteractionState(
        preferredUserId: Int?
    ) async throws -> (isLiked: Bool, isStored: Bool, likeCount: Int)? {
        let resolvedUserId: Int?
        if let preferredUserId, preferredUserId > 0 {
            resolvedUserId = preferredUserId
        } else if diary.userId > 0 {
            resolvedUserId = diary.userId
        } else {
            resolvedUserId = nil
        }

        if let resolvedUserId,
           let userFeedInteraction = try await findInteractionInUserFeeds(userId: resolvedUserId) {
            return userFeedInteraction
        }

        return try await findInteractionInMyFeeds()
    }

    private func findInteractionInUserFeeds(
        userId: Int
    ) async throws -> (isLiked: Bool, isStored: Bool, likeCount: Int)? {
        var page = DiaryService.defaultPage

        for _ in 0..<maxRefreshScanPageCount {
            let response = try await diaryService.fetchUserFeeds(
                userId: userId,
                page: page,
                size: DiaryService.defaultSize
            )

            if let targetDiary = response.content.first(where: { $0.diaryId == diary.diaryId }) {
                return (
                    isLiked: targetDiary.isLiked,
                    isStored: targetDiary.isStored,
                    likeCount: targetDiary.likeCount
                )
            }

            let nextPage = max(response.page.number, 0) + 1
            let totalPages = max(response.page.totalPages, 0)
            let hasNextByPage = nextPage < totalPages
            let hasNextByCount = response.content.count >= DiaryService.defaultSize
            guard hasNextByPage || hasNextByCount else {
                return nil
            }

            page = nextPage
        }

        return nil
    }

    private func findInteractionInMyFeeds() async throws -> (isLiked: Bool, isStored: Bool, likeCount: Int)? {
        var page = DiaryService.defaultPage

        for _ in 0..<maxRefreshScanPageCount {
            let response = try await diaryService.fetchMyFeeds(
                page: page,
                size: DiaryService.defaultSize
            )

            if let targetDiary = response.content.first(where: { $0.diaryId == diary.diaryId }) {
                return (
                    isLiked: targetDiary.isLiked,
                    isStored: targetDiary.isStored,
                    likeCount: targetDiary.likeCount
                )
            }

            let nextPage = max(response.page.number, 0) + 1
            let totalPages = max(response.page.totalPages, 0)
            let hasNextByPage = nextPage < totalPages
            let hasNextByCount = response.content.count >= DiaryService.defaultSize
            guard hasNextByPage || hasNextByCount else {
                return nil
            }

            page = nextPage
        }

        return nil
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

    private func resolveErrorMessage(from error: Error) -> String {
        if let diaryError = error as? DiaryServiceError {
            return diaryError.errorDescription ?? "요청 처리에 실패했어요."
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
