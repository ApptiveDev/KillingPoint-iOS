import Foundation

protocol DiaryServicing {
    func fetchMyFeeds(page: Int, size: Int) async throws -> MyDiaryFeedsResponse
}

enum DiaryServiceError: LocalizedError {
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

struct DiaryService: DiaryServicing {
    private let apiClient: APIClienting

    init(apiClient: APIClienting = APIClient.shared) {
        self.apiClient = apiClient
    }

    func fetchMyFeeds(page: Int = 0, size: Int = 5) async throws -> MyDiaryFeedsResponse {
        do {
            let request = APIRequest(
                path: "/diaries/my",
                method: .get,
                queryItems: [
                    URLQueryItem(name: "page", value: String(page)),
                    URLQueryItem(name: "size", value: String(size))
                ],
                requiresAuthorization: true
            )

            return try await apiClient.request(request, responseType: MyDiaryFeedsResponse.self)
        } catch {
            throw mapError(error)
        }
    }

    private func mapError(_ error: Error) -> DiaryServiceError {
        if let diaryServiceError = error as? DiaryServiceError {
            return diaryServiceError
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
