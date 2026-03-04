import Foundation

@MainActor
final class PlayKillingPartViewModel: ObservableObject {
    @Published private(set) var isEditMode = false
    @Published private(set) var isSavingOrder = false
    @Published var errorMessage: String?

    private let diaryService: DiaryServicing
    private var isRefetchingPlaybackFeeds = false

    init(diaryService: DiaryServicing = DiaryService()) {
        self.diaryService = diaryService
    }

    func beginEditing() {
        guard !isSavingOrder else { return }
        errorMessage = nil
        isEditMode = true
    }

    func completeEditing(with diaryIDs: [Int]) async -> Bool {
        guard isEditMode else { return true }
        guard !isSavingOrder else { return false }

        let hasDuplicateDiaryID = Set(diaryIDs).count != diaryIDs.count
        if hasDuplicateDiaryID {
            errorMessage = "플레이리스트 순서가 올바르지 않아요."
            return false
        }

        isSavingOrder = true
        errorMessage = nil
        defer { isSavingOrder = false }

        do {
            try await diaryService.updateMyDiaryOrder(
                request: DiaryOrderUpdateRequest(diaryIds: diaryIDs)
            )
            isEditMode = false
            return true
        } catch {
            if isRequestCancelled(error) { return false }
            errorMessage = resolveErrorMessage(from: error)
            return false
        }
    }

    func endEditingWithoutSave() {
        guard !isSavingOrder else { return }
        errorMessage = nil
        isEditMode = false
    }

    func refetchPlaybackFeeds(
        refetchInitialPage: @escaping () async -> Void,
        loadNextPageIfNeeded: @escaping () async -> Void,
        currentFeedCount: @escaping () -> Int,
        currentFeedIDs: @escaping () -> [Int]
    ) async -> PlaybackFeedRefetchResult {
        guard !isRefetchingPlaybackFeeds else { return .unchanged }

        isRefetchingPlaybackFeeds = true
        defer { isRefetchingPlaybackFeeds = false }

        let previousFeedIDs = currentFeedIDs()
        await refetchInitialPage()

        var previousFeedCount = -1
        var iteration = 0
        while previousFeedCount != currentFeedCount(), iteration < 200 {
            if Task.isCancelled { return .unchanged }
            previousFeedCount = currentFeedCount()
            await loadNextPageIfNeeded()
            iteration += 1
        }

        let refreshedFeedIDs = currentFeedIDs()
        return PlaybackFeedRefetchResult(
            hasFeedOrderingChanged: previousFeedIDs != refreshedFeedIDs
        )
    }

    private func resolveErrorMessage(from error: Error) -> String {
        if let diaryError = error as? DiaryServiceError {
            return diaryError.errorDescription ?? "요청 처리에 실패했어요."
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

struct PlaybackFeedRefetchResult {
    let hasFeedOrderingChanged: Bool

    static var unchanged: Self {
        PlaybackFeedRefetchResult(hasFeedOrderingChanged: false)
    }
}
