import Foundation

protocol AuthenticationServicing {
    func login(email: String, password: String) async -> Bool
    func loginWithKakao(accessToken: String) async throws -> KakaoSocialLoginResponse
    func logout() async throws
    func deleteMyAccount() async throws
}

enum AuthenticationServiceError: LocalizedError {
    case invalidKakaoAccessToken
    case invalidResponse
    case serverError(statusCode: Int, message: String?)
    case decodingFailed
    case requestEncodingFailed
    case sessionExpired
    case networkFailure(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidKakaoAccessToken:
            return "카카오 액세스 토큰이 유효하지 않아요."
        case .invalidResponse:
            return "서버 응답을 확인할 수 없어요."
        case .serverError(let statusCode, let message):
            if let message, !message.isEmpty {
                print("인증 요청 처리에 실패했어요. (status: \(statusCode), message: \(message))")
                return "요청 처리에 실패했어요."
            }
            print("인증 요청 처리에 실패했어요. (status: \(statusCode)")
            return "요청 처리에 실패했어요."
        case .decodingFailed:
            return "응답 파싱에 실패했어요."
        case .requestEncodingFailed:
            return "요청 생성에 실패했어요."
        case .sessionExpired:
            return "세션이 만료되었어요. 다시 로그인해 주세요."
        case .networkFailure(let message):
            return message
        }
    }
}

struct AuthenticationService: AuthenticationServicing {
    private let apiClient: APIClienting
    private let tokenStore: TokenStoring

    init(
        apiClient: APIClienting = APIClient.shared,
        tokenStore: TokenStoring = TokenStore.shared
    ) {
        self.apiClient = apiClient
        self.tokenStore = tokenStore
    }

    func login(email: String, password: String) async -> Bool {
        try? await Task.sleep(for: .milliseconds(600))
        return !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func loginWithKakao(accessToken: String) async throws -> KakaoSocialLoginResponse {
        let trimmedToken = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            throw AuthenticationServiceError.invalidKakaoAccessToken
        }

        let requestBody: Data
        do {
            requestBody = try JSONEncoder().encode(
                KakaoSocialLoginRequest(accessToken: trimmedToken)
            )
        } catch {
            throw AuthenticationServiceError.requestEncodingFailed
        }

        do {
            var request = APIRequest(
                path: "/oauth2/kakao",
                method: .post,
                requiresAuthorization: false,
                body: requestBody
            )
            request.headers["Content-Type"] = "application/json"
            request.headers["Accept"] = "application/json"

            let response = try await apiClient.request(
                request,
                responseType: KakaoSocialLoginResponse.self
            )

            tokenStore.save(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken
            )
            return response
        } catch {
            throw mapError(error)
        }
    }

    func logout() async throws {
        do {
            let request = APIRequest(
                path: "/users/logout",
                method: .post,
                requiresAuthorization: true
            )
            try await apiClient.request(request)
            tokenStore.clearTokens()
        } catch {
            throw mapError(error)
        }
    }

    func deleteMyAccount() async throws {
        do {
            let request = APIRequest(
                path: "/users/my",
                method: .delete,
                requiresAuthorization: true
            )
            try await apiClient.request(request)
            tokenStore.clearTokens()
        } catch {
            throw mapError(error)
        }
    }

    private func mapError(_ error: Error) -> AuthenticationServiceError {
        if let authError = error as? AuthenticationServiceError {
            return authError
        }

        if let apiError = error as? APIClientError {
            switch apiError {
            case .invalidResponse:
                return .invalidResponse
            case .missingAccessToken, .missingRefreshToken, .unauthorized:
                return .sessionExpired
            case .serverError(let statusCode, let message):
                return .serverError(statusCode: statusCode, message: message)
            case .decodingFailed:
                return .decodingFailed
            }
        }

        return .networkFailure(message: "네트워크 요청 중 오류가 발생했어요.")
    }
}
