import Foundation

protocol UserServicing {
    func fetchMyUser() async throws -> UserModel
    func fetchUserStatics(userId: Int) async throws -> UserStaticsModel
}

enum UserServiceError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int, message: String?)
    case decodingFailed
    case sessionExpired
    case networkFailure(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "서버 응답을 확인할 수 없어요."
        case .serverError(_, let message):
            return message ?? "요청 처리에 실패했어요."
        case .decodingFailed:
            return "응답 파싱에 실패했어요."
        case .sessionExpired:
            return "세션이 만료되었어요. 다시 로그인해 주세요."
        case .networkFailure(let message):
            return message
        }
    }
}

struct UserService: UserServicing {
    private let apiClient: APIClienting

    init(apiClient: APIClienting = APIClient.shared) {
        self.apiClient = apiClient
    }

    func fetchMyUser() async throws -> UserModel {
        do {
            let request = APIRequest(
                path: "/users/my",
                method: .get,
                requiresAuthorization: true
            )

            return try await apiClient.request(request, responseType: UserModel.self)
        } catch {
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
                return .serverError(statusCode: statusCode, message: message)
            case .decodingFailed:
                return .decodingFailed
            }
        }

        return .networkFailure(message: "네트워크 요청 중 오류가 발생했어요.")
    }
}
