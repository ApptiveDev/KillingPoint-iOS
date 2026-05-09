import Foundation

@MainActor
final class BlocklistViewModel: ObservableObject {
    @Published var searchText: String = "" {
        didSet {
            applySearchFilter()
        }
    }
    @Published private(set) var blockedUsers: [UserModel] = []
    @Published private(set) var filteredBlockedUsers: [UserModel] = []
    @Published private(set) var totalBlockedUsers = 0
    @Published private(set) var isLoadingInitial = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var isUnblockingUser = false
    @Published var errorMessage: String?
    @Published var unblockErrorMessage: String?

    private let userService: UserServicing
    private let pageSize = 20
    private var hasLoadedInitialData = false
    private var nextPage = UserService.defaultPage
    private var hasNextPage = true

    init(userService: UserServicing = UserService()) {
        self.userService = userService
    }

    var blockedUsersCountText: String {
        "\(totalBlockedUsers)명"
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
            let response = try await userService.fetchBlockedUsers(
                page: UserService.defaultPage,
                size: pageSize
            )
            blockedUsers = response.content
            totalBlockedUsers = max(response.page.totalElements, response.content.count)
            updatePaging(from: response)
            applySearchFilter()
            hasLoadedInitialData = true
        } catch {
            if isRequestCancelled(error) { return }
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    func loadMoreIfNeeded(currentUserId: Int) async {
        guard blockedUsers.last?.userId == currentUserId else { return }
        guard hasNextPage else { return }
        guard !isLoadingInitial, !isLoadingMore else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let response = try await userService.fetchBlockedUsers(page: nextPage, size: pageSize)
            appendBlockedUsers(with: response.content)
            totalBlockedUsers = max(response.page.totalElements, blockedUsers.count)
            updatePaging(from: response)
            applySearchFilter()
        } catch {
            if isRequestCancelled(error) { return }
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    func unblockUser(blockedId: Int) async -> Bool {
        guard blockedId > 0 else { return false }
        guard !isUnblockingUser else { return false }

        isUnblockingUser = true
        unblockErrorMessage = nil
        defer { isUnblockingUser = false }

        do {
            try await userService.unblockUser(blockedId: blockedId)
            blockedUsers.removeAll { $0.userId == blockedId }
            totalBlockedUsers = max(totalBlockedUsers - 1, 0)
            applySearchFilter()
            return true
        } catch {
            if isRequestCancelled(error) { return false }
            unblockErrorMessage = resolveErrorMessage(from: error)
            return false
        }
    }

    func clearUnblockError() {
        unblockErrorMessage = nil
    }

    private func appendBlockedUsers(with newUsers: [UserModel]) {
        let existingIDs = Set(blockedUsers.map(\.userId))
        let filtered = newUsers.filter { !existingIDs.contains($0.userId) }
        blockedUsers.append(contentsOf: filtered)
    }

    private func updatePaging(from response: UserSearchResponse) {
        nextPage = max(response.page.number, 0) + 1
        let totalPages = max(response.page.totalPages, 0)
        let hasNextByPage = nextPage < totalPages
        let hasNextByCount = response.content.count >= pageSize
        hasNextPage = hasNextByPage || hasNextByCount
    }

    private func applySearchFilter() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            filteredBlockedUsers = blockedUsers
            return
        }

        filteredBlockedUsers = blockedUsers.filter { user in
            user.username.lowercased().contains(query)
            || user.tag.lowercased().contains(query)
        }
    }

    private func resolveErrorMessage(from error: Error) -> String {
        if let userError = error as? UserServiceError {
            return userError.errorDescription ?? "차단 목록 요청에 실패했어요."
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
