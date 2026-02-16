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
    @Published var errorMessage: String?

    private let authenticationService: AuthenticationServicing
    private let userService: UserServicing
    private let diaryService: DiaryServicing

    private var hasLoadedProfile = false
    private var hasLoadedUserStatics = false
    private var hasLoadedMyFeeds = false
    private var isLoadingProfile = false
    private var isLoadingUserStatics = false
    private var isLoadingMyFeeds = false

    init(
        authenticationService: AuthenticationServicing,
        userService: UserServicing = UserService(),
        diaryService: DiaryServicing = DiaryService()
    ) {
        self.authenticationService = authenticationService
        self.userService = userService
        self.diaryService = diaryService
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

    func loadInitialDataIfNeeded() async {
        async let profileLoad: Void = loadMyProfileIfNeeded()
        async let feedLoad: Void = loadMyFeedsIfNeeded()
        _ = await (profileLoad, feedLoad)
    }

    func loadMyProfileIfNeeded() async {
        guard !hasLoadedProfile else { return }
        await loadMyProfile()
    }

    func loadMyFeedsIfNeeded(page: Int = 0, size: Int = 5) async {
        guard !hasLoadedMyFeeds else { return }
        await loadMyFeeds(page: page, size: size)
    }

    func formattedUpdateDate(from rawUpdateDate: String) -> String {
        let datePart = rawUpdateDate.split(separator: "T").first.map(String.init) ?? rawUpdateDate
        return datePart.replacingOccurrences(of: "-", with: ".")
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

        defer { isLoadingProfile = false }

        do {
            let fetchedUser = try await userService.fetchMyUser()
            user = fetchedUser
            hasLoadedProfile = true

            await loadUserStaticsIfNeeded(userId: fetchedUser.userId)
        } catch {
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    private func loadUserStaticsIfNeeded(userId: Int) async {
        guard !hasLoadedUserStatics else { return }
        guard !isLoadingUserStatics else { return }

        isLoadingUserStatics = true
        defer { isLoadingUserStatics = false }

        do {
            userStatics = try await userService.fetchUserStatics(userId: userId)
            hasLoadedUserStatics = true
        } catch {
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    private func loadMyFeeds(page: Int, size: Int) async {
        guard !isLoadingMyFeeds else { return }

        isLoadingMyFeeds = true
        errorMessage = nil

        defer { isLoadingMyFeeds = false }

        do {
            let response = try await diaryService.fetchMyFeeds(page: page, size: size)
            myFeeds = response.content
            hasLoadedMyFeeds = true
        } catch {
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    private func resolveErrorMessage(from error: Error) -> String {
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
}
