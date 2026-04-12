import Foundation

@MainActor
final class MyCollectionStoresViewModel: ObservableObject {
    @Published private(set) var storedDiaries: [StoredDiaryFeedModel] = []
    @Published private(set) var isLoadingInitial = false
    @Published private(set) var isLoadingMore = false
    @Published var errorMessage: String?

    private let diaryService: DiaryServicing
    private let pageSize = DiaryService.defaultSize
    private var hasLoadedInitial = false
    private var isLoadingStoredDiaries = false
    private var nextPage = DiaryService.defaultPage
    private var hasNextPage = true
    private var hasPendingBottomPaginationRequest = false
    private var hasPendingFocusRefetchRequest = false

    init(diaryService: DiaryServicing = DiaryService()) {
        self.diaryService = diaryService
    }

    func loadInitialDataIfNeeded() async {
        guard !hasLoadedInitial else { return }
        await loadStoredDiaries(
            page: DiaryService.defaultPage,
            size: pageSize,
            mode: .initial
        )
    }

    func refetchStoredDiariesOnFocus() async {
        guard !isLoadingStoredDiaries else {
            hasPendingFocusRefetchRequest = true
            return
        }

        hasPendingFocusRefetchRequest = false
        hasPendingBottomPaginationRequest = false
        hasLoadedInitial = false
        nextPage = DiaryService.defaultPage
        hasNextPage = true
        errorMessage = nil

        await loadStoredDiaries(
            page: DiaryService.defaultPage,
            size: pageSize,
            mode: .initial
        )
    }

    func loadMoreStoredDiariesIfNeeded(currentDiaryId: Int) async {
        guard storedDiaries.last?.diaryId == currentDiaryId else { return }
        guard hasLoadedInitial else { return }
        guard hasNextPage else { return }
        guard !isLoadingStoredDiaries else {
            hasPendingBottomPaginationRequest = true
            return
        }

        await loadStoredDiaries(page: nextPage, size: pageSize, mode: .pagination)
    }

    func loadMoreStoredDiariesFromBottomIfNeeded() async {
        guard let lastDiaryId = storedDiaries.last?.diaryId else { return }
        await loadMoreStoredDiariesIfNeeded(currentDiaryId: lastDiaryId)
    }

    func removeStoredDiaryLocally(diaryId: Int) {
        storedDiaries.removeAll { $0.diaryId == diaryId }
    }

    private func loadStoredDiaries(page: Int, size: Int, mode: StoreDiaryLoadMode) async {
        guard !isLoadingStoredDiaries else { return }

        isLoadingStoredDiaries = true
        if mode == .initial {
            isLoadingInitial = true
            errorMessage = nil
        } else {
            isLoadingMore = true
        }

        defer {
            isLoadingStoredDiaries = false
            if mode == .initial {
                isLoadingInitial = false
            } else {
                isLoadingMore = false
            }
            triggerPendingFocusRefetchIfNeeded()
            triggerPendingBottomPaginationIfNeeded()
        }

        do {
            let response = try await diaryService.fetchStoredDiaries(page: page, size: size)
            if mode == .initial {
                storedDiaries = response.content
            } else {
                let existingDiaryIDs = Set(storedDiaries.map(\.diaryId))
                let newDiaries = response.content.filter { !existingDiaryIDs.contains($0.diaryId) }
                storedDiaries.append(contentsOf: newDiaries)
                if newDiaries.isEmpty {
                    hasLoadedInitial = true
                    hasNextPage = false
                    return
                }
            }

            hasLoadedInitial = true
            let fetchedPage = max(response.page.number, 0)
            nextPage = fetchedPage + 1
            let totalPages = max(response.page.totalPages, 0)
            let hasNextByPage = nextPage < totalPages
            let hasNextByCount = response.content.count >= size
            hasNextPage = hasNextByPage || hasNextByCount
        } catch {
            if isRequestCancelled(error) { return }
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    private func resolveErrorMessage(from error: Error) -> String {
        if let diaryServiceError = error as? DiaryServiceError {
            return diaryServiceError.errorDescription ?? "요청 처리에 실패했어요."
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
        guard hasLoadedInitial else { return }
        guard hasNextPage else { return }
        guard !isLoadingStoredDiaries else { return }

        Task {
            await loadMoreStoredDiariesFromBottomIfNeeded()
        }
    }

    private func triggerPendingFocusRefetchIfNeeded() {
        guard hasPendingFocusRefetchRequest else { return }
        guard !isLoadingStoredDiaries else { return }

        hasPendingFocusRefetchRequest = false
        Task {
            await refetchStoredDiariesOnFocus()
        }
    }

    private enum StoreDiaryLoadMode {
        case initial
        case pagination
    }
}
