import Foundation

@MainActor
final class ProfileSettingViewModel: ObservableObject {
    @Published private(set) var user: UserModel?
    @Published var tagDraft: String = ""
    @Published private(set) var isProcessing = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let userService: UserServicing

    init(
        user: UserModel? = nil,
        userService: UserServicing = UserService()
    ) {
        self.userService = userService
        syncUser(user)
    }

    var displayName: String {
        let trimmed = user?.username.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "킬링파트 사용자" : trimmed
    }

    var displayTag: String {
        let trimmed = user?.tag.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return "@killingpart_user" }
        return trimmed.hasPrefix("@") ? trimmed : "@\(trimmed)"
    }

    var profileImageURL: URL? {
        user?.profileImageURL
    }

    var canSubmitTagUpdate: Bool {
        guard !isProcessing else { return false }
        guard let user else { return false }
        let newTag = normalizedTag(from: tagDraft)
        guard !newTag.isEmpty else { return false }
        guard validateTag(newTag) == nil else { return false }
        return newTag != normalizedTag(from: user.tag)
    }

    func syncUser(_ user: UserModel?) {
        self.user = user
        tagDraft = user?.tag ?? ""
    }

    func updateTag() async -> UserModel? {
        guard !isProcessing else { return nil }

        let newTag = normalizedTag(from: tagDraft)
        guard !newTag.isEmpty else {
            errorMessage = "변경할 태그를 입력해 주세요."
            successMessage = nil
            return nil
        }

        if let validationMessage = validateTag(newTag) {
            errorMessage = validationMessage
            successMessage = nil
            return nil
        }

        if let currentTag = user?.tag, normalizedTag(from: currentTag) == newTag {
            errorMessage = "현재와 다른 태그를 입력해 주세요."
            successMessage = nil
            return nil
        }

        isProcessing = true
        errorMessage = nil
        successMessage = nil
        defer { isProcessing = false }

        do {
            let updatedUser = try await userService.updateMyTag(tag: newTag)
            applyUpdatedUser(updatedUser)
            successMessage = "태그를 변경했어요."
            return updatedUser
        } catch {
            if isRequestCancelled(error) { return nil }
            errorMessage = resolveErrorMessage(from: error)
            return nil
        }
    }

    func deleteProfileImage() async -> UserModel? {
        guard !isProcessing else { return nil }

        isProcessing = true
        errorMessage = nil
        successMessage = nil
        defer { isProcessing = false }

        do {
            let updatedUser = try await userService.deleteMyProfileImage()
            applyUpdatedUser(updatedUser)
            successMessage = "기본 프로필 이미지로 변경했어요."
            return updatedUser
        } catch {
            if isRequestCancelled(error) { return nil }
            errorMessage = resolveErrorMessage(from: error)
            return nil
        }
    }

    func updateProfileImage(with imageData: Data) async -> UserModel? {
        guard !isProcessing else { return nil }
        guard !imageData.isEmpty else {
            errorMessage = "업로드할 이미지를 불러오지 못했어요."
            successMessage = nil
            return nil
        }

        isProcessing = true
        errorMessage = nil
        successMessage = nil
        defer { isProcessing = false }

        do {
            let presignedURLResponse = try await userService.issuePresignedURL()
            guard let presignedURL = URL(string: presignedURLResponse.presignedUrl) else {
                errorMessage = "업로드 URL을 확인할 수 없어요."
                return nil
            }

            try await userService.uploadImageToPresignedURL(
                imageData: imageData,
                presignedURL: presignedURL
            )

            guard let uploadTargetURLString = publicURLString(from: presignedURLResponse.presignedUrl) else {
                errorMessage = "업로드 URL을 확인할 수 없어요."
                return nil
            }

            let updatedUser = try await userService.updateMyProfileImage(
                request: UpdateMyProfileImageRequest(
                    id: presignedURLResponse.id,
                    presignedUrl: uploadTargetURLString
                )
            )
            applyUpdatedUser(updatedUser)
            successMessage = "프로필 이미지를 변경했어요."
            return updatedUser
        } catch {
            if isRequestCancelled(error) { return nil }
            errorMessage = resolveErrorMessage(from: error)
            return nil
        }
    }

    private func applyUpdatedUser(_ user: UserModel) {
        self.user = user
        tagDraft = user.tag
    }

    private func normalizedTag(from rawTag: String) -> String {
        let trimmed = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.hasPrefix("@") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    private func validateTag(_ tag: String) -> String? {
        guard (4...30).contains(tag.count) else {
            return "tag는 4자 이상 30자 이하이어야 합니다."
        }

        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_.")
        if tag.rangeOfCharacter(from: allowedCharacters.inverted) != nil
            || tag.hasPrefix(".")
            || tag.hasSuffix(".")
            || tag.contains("..")
        {
            return "영문 소문자, 숫자, '_', '.'만 사용 가능하며, '.'으로 시작·끝낼 수 없고 연속 사용 불가합니다."
        }

        return nil
    }

    private func publicURLString(from presignedURLString: String) -> String? {
        let trimmed = presignedURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard var components = URLComponents(string: trimmed) else {
            return trimmed.split(separator: "?").first.map(String.init)
        }

        components.query = nil
        components.fragment = nil
        return components.url?.absoluteString
    }

    private func resolveErrorMessage(from error: Error) -> String {
        if let userServiceError = error as? UserServiceError {
            return userServiceError.errorDescription ?? "프로필 설정 요청에 실패했어요."
        }

        if let apiError = error as? APIClientError {
            return apiError.errorDescription ?? "프로필 설정 요청에 실패했어요."
        }

        if let localizedError = error as? LocalizedError {
            return localizedError.errorDescription ?? "프로필 설정 요청에 실패했어요."
        }

        return "프로필 설정 요청에 실패했어요."
    }

    private func isRequestCancelled(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
