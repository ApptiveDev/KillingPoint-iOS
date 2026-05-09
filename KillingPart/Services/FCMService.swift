import Foundation

protocol FCMServicing {
    func registerToken(_ token: String) async throws
    func deleteToken() async throws
}

enum FCMServiceError: LocalizedError {
    case requestEncodingFailed
    case sessionExpired
    case serverError(statusCode: Int, message: String?)
    case networkFailure(message: String)

    var errorDescription: String? {
        switch self {
        case .requestEncodingFailed:
            return "요청 생성에 실패했어요."
        case .sessionExpired:
            return "세션이 만료되었어요. 다시 로그인해 주세요."
        case .serverError(_, let message):
            return message ?? "요청 처리에 실패했어요."
        case .networkFailure(let message):
            return message
        }
    }
}

struct FCMService: FCMServicing {
    private let apiClient: APIClienting

    init(apiClient: APIClienting = APIClient.shared) {
        self.apiClient = apiClient
    }

    func registerToken(_ token: String) async throws {
        let requestBody: Data
        do {
            requestBody = try JSONEncoder().encode(FCMTokenRequest(token: token))
        } catch {
            throw FCMServiceError.requestEncodingFailed
        }

        do {
            let request = APIRequest(
                path: "/fcm/tokens",
                method: .post,
                requiresAuthorization: true,
                body: requestBody
            )
            try await apiClient.request(request)
            print("[FCM] 서버에 토큰 등록 완료")
        } catch {
            throw mapError(error)
        }
    }

    func deleteToken() async throws {
        do {
            let request = APIRequest(
                path: "/fcm/tokens",
                method: .delete,
                requiresAuthorization: true
            )
            try await apiClient.request(request)
            print("[FCM] 서버에서 토큰 삭제 완료")
        } catch {
            throw mapError(error)
        }
    }

    private func mapError(_ error: Error) -> FCMServiceError {
        if let fcmError = error as? FCMServiceError {
            return fcmError
        }

        if let apiError = error as? APIClientError {
            switch apiError {
            case .missingAccessToken, .missingRefreshToken, .unauthorized:
                return .sessionExpired
            case .serverError(let statusCode, let message):
                return .serverError(statusCode: statusCode, message: message)
            default:
                break
            }
        }

        return .networkFailure(message: "네트워크 요청 중 오류가 발생했어요.")
    }
}

private struct FCMTokenRequest: Encodable {
    let token: String
}
