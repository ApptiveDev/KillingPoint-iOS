import Foundation

protocol UserServicing {
    func fetchMyUser() async throws -> UserModel
    func fetchInitSettings() async throws -> UserInitSettingsResponse
    func submitPolicyAgreement(agreements: [PolicyAgreementItem]) async throws
    func fetchUserStatics(userId: Int) async throws -> UserStaticsModel
    func searchUsers(searchCond: String?, page: Int, size: Int) async throws -> UserSearchResponse
    func blockUser(blockedId: Int) async throws
    func fetchBlockedUsers(page: Int, size: Int) async throws -> UserSearchResponse
    func unblockUser(blockedId: Int) async throws
    func deleteMyProfileImage() async throws -> UserModel
    func issuePresignedURL() async throws -> PresignedURLResponse
    func uploadImageToPresignedURL(imageData: Data, presignedURL: URL) async throws
    func updateMyProfileImage(request: UpdateMyProfileImageRequest) async throws -> UserModel
    func updateMyUsername(username: String) async throws -> UserModel
    func updateMyTag(tag: String) async throws -> UserModel
}

enum UserServiceError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int, message: String?)
    case decodingFailed
    case requestEncodingFailed
    case sessionExpired
    case uploadFailed(statusCode: Int, message: String?)
    case networkFailure(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "서버 응답을 확인할 수 없어요."
        case .serverError(_, let message):
            return message ?? "요청 처리에 실패했어요."
        case .decodingFailed:
            return "응답 파싱에 실패했어요."
        case .requestEncodingFailed:
            return "요청 생성에 실패했어요."
        case .sessionExpired:
            return "세션이 만료되었어요. 다시 로그인해 주세요."
        case .uploadFailed(_, let message):
            return message ?? "프로필 이미지 업로드에 실패했어요."
        case .networkFailure(let message):
            return message
        }
    }
}

struct UserService: UserServicing {
    static let defaultPage = 0
    static let defaultSize = 5

    private let apiClient: APIClienting
    private let session: URLSession

    init(
        apiClient: APIClienting = APIClient.shared,
        session: URLSession = .shared
    ) {
        self.apiClient = apiClient
        self.session = session
    }

    func fetchMyUser() async throws -> UserModel {
        do {
            let request = APIRequest(
                path: "/users/my",
                method: .get,
                requiresAuthorization: true
            )

            let response = try await apiClient.request(request, responseType: UserResponseDTO.self)
            return response.toModel()
        } catch {
            throw mapError(error)
        }
    }

    func fetchInitSettings() async throws -> UserInitSettingsResponse {
        do {
            let request = APIRequest(
                path: "/users/init-settings",
                method: .get,
                queryItems: [
                    URLQueryItem(name: "clientVersion", value: Self.clientVersion),
                    URLQueryItem(name: "clientType", value: Self.clientType)
                ],
                requiresAuthorization: true
            )
            return try await apiClient.request(request, responseType: UserInitSettingsResponse.self)
        } catch {
            throw mapError(error)
        }
    }

    func submitPolicyAgreement(agreements: [PolicyAgreementItem]) async throws {
        let requestBody: Data
        do {
            requestBody = try JSONEncoder().encode(PolicyAgreementRequest(agreements: agreements))
        } catch {
            throw UserServiceError.requestEncodingFailed
        }

        do {
            var request = APIRequest(
                path: "/users/policy-agreement",
                method: .post,
                requiresAuthorization: true,
                body: requestBody
            )
            request.headers["Accept"] = "application/json"
            request.headers["Content-Type"] = "application/json"
            try await apiClient.request(request)
        } catch {
            if isRequestCancelled(error) { throw error }
            throw mapError(error)
        }
    }

    func fetchUserStatics(userId: Int) async throws -> UserStaticsModel {
        do {
            let request = APIRequest(
                path: "/users/\(userId)/statics",
                method: .get,
                requiresAuthorization: true
            )

            return try await apiClient.request(request, responseType: UserStaticsModel.self)
        } catch {
            throw mapError(error)
        }
    }

    func searchUsers(
        searchCond: String? = nil,
        page: Int = Self.defaultPage,
        size: Int = Self.defaultSize
    ) async throws -> UserSearchResponse {
        let resolvedPage = max(page, Self.defaultPage)
        let resolvedSize = size > 0 ? size : Self.defaultSize
        let trimmedSearchCond = searchCond?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var queryItems = [
            URLQueryItem(name: "page", value: String(resolvedPage)),
            URLQueryItem(name: "size", value: String(resolvedSize))
        ]

        if !trimmedSearchCond.isEmpty {
            queryItems.insert(URLQueryItem(name: "searchCond", value: trimmedSearchCond), at: 0)
        }

        do {
            let request = APIRequest(
                path: "/users",
                method: .get,
                queryItems: queryItems,
                requiresAuthorization: true
            )
            let response = try await apiClient.request(request, responseType: UserSearchResponseDTO.self)
            return response.toModel()
        } catch {
            if isRequestCancelled(error) { throw error }
            throw mapError(error)
        }
    }
    
    func blockUser(blockedId: Int) async throws {
        do {
            let request = APIRequest(
                path: "/users/\(blockedId)/blocks",
                method: .post,
                requiresAuthorization: true
            )
            try await apiClient.request(request)
        } catch {
            if isRequestCancelled(error) { throw error }
            throw mapError(error)
        }
    }
    
    func fetchBlockedUsers(page: Int = Self.defaultPage, size: Int = Self.defaultSize) async throws -> UserSearchResponse {
        let resolvedPage = max(page, Self.defaultPage)
        let resolvedSize = size > 0 ? size : Self.defaultSize

        do {
            let request = APIRequest(
                path: "/users/blocks",
                method: .get,
                queryItems: [
                    URLQueryItem(name: "page", value: String(resolvedPage)),
                    URLQueryItem(name: "size", value: String(resolvedSize))
                ],
                requiresAuthorization: true
            )
            let response = try await apiClient.request(request, responseType: UserSearchResponseDTO.self)
            return response.toModel()
        } catch {
            if isRequestCancelled(error) { throw error }
            throw mapError(error)
        }
    }
    
    func unblockUser(blockedId: Int) async throws {
        do {
            let request = APIRequest(
                path: "/users/\(blockedId)/blocks",
                method: .delete,
                requiresAuthorization: true
            )
            try await apiClient.request(request)
        } catch {
            if isRequestCancelled(error) { throw error }
            throw mapError(error)
        }
    }

    func deleteMyProfileImage() async throws -> UserModel {
        do {
            let request = APIRequest(
                path: "/users/my/profile-image",
                method: .delete,
                requiresAuthorization: true
            )
            let response = try await apiClient.request(request, responseType: UserResponseDTO.self)
            return response.toModel()
        } catch {
            if isRequestCancelled(error) { throw error }
            throw mapError(error)
        }
    }

    func issuePresignedURL() async throws -> PresignedURLResponse {
        do {
            let request = APIRequest(
                path: "/presigned-url",
                method: .get,
                requiresAuthorization: true
            )
            return try await apiClient.request(request, responseType: PresignedURLResponse.self)
        } catch {
            if isRequestCancelled(error) { throw error }
            throw mapError(error)
        }
    }

    func uploadImageToPresignedURL(imageData: Data, presignedURL: URL) async throws {
        var request = URLRequest(url: presignedURL)
        request.httpMethod = HTTPMethod.put.rawValue
        request.httpBody = imageData

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw UserServiceError.invalidResponse
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw UserServiceError.uploadFailed(
                    statusCode: httpResponse.statusCode,
                    message: responseMessage(from: data)
                )
            }
        } catch {
            if isRequestCancelled(error) { throw error }
            if let userServiceError = error as? UserServiceError {
                throw userServiceError
            }
            throw UserServiceError.networkFailure(message: "프로필 이미지 업로드 중 네트워크 오류가 발생했어요.")
        }
    }

    func updateMyProfileImage(request: UpdateMyProfileImageRequest) async throws -> UserModel {
        let requestBody: Data
        do {
            requestBody = try JSONEncoder().encode(request)
        } catch {
            throw UserServiceError.requestEncodingFailed
        }

        do {
            var apiRequest = APIRequest(
                path: "/users/my/profile-image",
                method: .patch,
                requiresAuthorization: true,
                body: requestBody
            )
            apiRequest.headers["Accept"] = "application/json"
            apiRequest.headers["Content-Type"] = "application/json"
            let response = try await apiClient.request(apiRequest, responseType: UserResponseDTO.self)
            return response.toModel()
        } catch {
            if isRequestCancelled(error) { throw error }
            throw mapError(error)
        }
    }

    func updateMyTag(tag: String) async throws -> UserModel {
        let requestBody: Data
        do {
            requestBody = try JSONEncoder().encode(UpdateMyTagRequest(tag: tag))
        } catch {
            throw UserServiceError.requestEncodingFailed
        }

        do {
            var apiRequest = APIRequest(
                path: "/users/my/tags",
                method: .patch,
                requiresAuthorization: true,
                body: requestBody
            )
            apiRequest.headers["Accept"] = "application/json"
            apiRequest.headers["Content-Type"] = "application/json"
            let response = try await apiClient.request(apiRequest, responseType: UserResponseDTO.self)
            return response.toModel()
        } catch {
            if isRequestCancelled(error) { throw error }
            throw mapError(error)
        }
    }

    func updateMyUsername(username: String) async throws -> UserModel {
        let requestBody: Data
        do {
            requestBody = try JSONEncoder().encode(UpdateMyUsernameRequest(username: username))
        } catch {
            throw UserServiceError.requestEncodingFailed
        }

        do {
            var request = APIRequest(
                path: "/users/my/names",
                method: .patch,
                requiresAuthorization: true,
                body: requestBody
            )
            request.headers["Accept"] = "application/json"
            request.headers["Content-Type"] = "application/json"
            let response = try await apiClient.request(request, responseType: UserResponseDTO.self)
            return response.toModel()
        } catch {
            if isRequestCancelled(error) { throw error }
            throw mapError(error)
        }
    }

    private func mapError(_ error: Error) -> UserServiceError {
        if let userServiceError = error as? UserServiceError {
            return userServiceError
        }

        if let apiError = error as? APIClientError {
            switch apiError {
            case .invalidResponse:
                return .invalidResponse
            case .missingAccessToken, .missingRefreshToken, .unauthorized:
                return .sessionExpired
            case .serverError(let statusCode, let message):
                return .serverError(
                    statusCode: statusCode,
                    message: normalizeServerErrorMessage(message)
                )
            case .decodingFailed:
                return .decodingFailed
            }
        }

        return .networkFailure(message: "네트워크 요청 중 오류가 발생했어요.")
    }

    private func normalizeServerErrorMessage(_ rawMessage: String?) -> String? {
        guard
            let rawMessage = rawMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
            !rawMessage.isEmpty
        else {
            return nil
        }

        guard
            rawMessage.first == "{",
            let data = rawMessage.data(using: .utf8),
            let parsed = try? JSONDecoder().decode(UserServiceErrorResponse.self, from: data)
        else {
            return rawMessage
        }

        if let message = parsed.message?.trimmingCharacters(in: .whitespacesAndNewlines),
           !message.isEmpty {
            return message
        }

        let fieldMessages = (parsed.fieldErrors ?? [])
            .flatMap(\.values)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let globalMessages = (parsed.globalErrors ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let merged = fieldMessages + globalMessages
        guard !merged.isEmpty else { return rawMessage }
        return merged.joined(separator: "\n")
    }

    private func responseMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        guard let body = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !body.isEmpty
        else {
            return nil
        }
        return body
    }

    private func isRequestCancelled(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    private static var clientVersion: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let resolved = (shortVersion?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? shortVersion
            : buildVersion) ?? "0.0.0"
        return resolved
    }

    private static let clientType = "IOS"
}

private struct UserServiceErrorResponse: Decodable {
    let message: String?
    let fieldErrors: [[String: String]]?
    let globalErrors: [String]?
}
