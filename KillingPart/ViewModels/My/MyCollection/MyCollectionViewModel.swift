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
    @Published var errorMessage: String?

    private let authenticationService: AuthenticationServicing
    private let userService: UserServicing

    private var hasLoadedProfile = false
    private var isLoadingProfile = false

    init(
        authenticationService: AuthenticationServicing,
        userService: UserServicing = UserService()
    ) {
        self.authenticationService = authenticationService
        self.userService = userService
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

    func loadMyProfileIfNeeded() async {
        guard !hasLoadedProfile else { return }
        await loadMyProfile()
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
            user = try await userService.fetchMyUser()
            hasLoadedProfile = true
        } catch {
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    private func resolveErrorMessage(from error: Error) -> String {
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
