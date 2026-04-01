import Foundation

protocol SubscribeServicing {
    func fetchSubscribers(userId: Int, page: Int, size: Int) async throws -> SubscribeListResponse
    func fetchSubscribes(userId: Int, page: Int, size: Int) async throws -> SubscribeListResponse
    func subscribe(to subscribeToUserId: Int) async throws
    func unsubscribe(from subscribeToUserId: Int) async throws
}

enum SubscribeServiceError: LocalizedError {
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

struct SubscribeService: SubscribeServicing {
    static let defaultPage = 0
    static let defaultSize = 5

    private let apiClient: APIClienting

    init(apiClient: APIClienting = APIClient.shared) {
        self.apiClient = apiClient
    }

    func fetchSubscribers(
        userId: Int,
        page: Int = Self.defaultPage,
        size: Int = Self.defaultSize
    ) async throws -> SubscribeListResponse {
        let resolvedPage = max(page, Self.defaultPage)
        let resolvedSize = size > 0 ? size : Self.defaultSize

        do {
            let request = APIRequest(
                path: "/subscribes/\(userId)/fans",
                method: .get,
                queryItems: [
                    URLQueryItem(name: "page", value: String(resolvedPage)),
                    URLQueryItem(name: "size", value: String(resolvedSize))
                ],
                requiresAuthorization: true
            )

            return try await apiClient.request(request, responseType: SubscribeListResponse.self)
        } catch {
            if isRequestCancelled(error) { throw error }
            throw mapError(error)
        }
    }

    func fetchSubscribes(
        userId: Int,
        page: Int = Self.defaultPage,
        size: Int = Self.defaultSize
    ) async throws -> SubscribeListResponse {
        let resolvedPage = max(page, Self.defaultPage)
        let resolvedSize = size > 0 ? size : Self.defaultSize

        do {
            let request = APIRequest(
                path: "/subscribes/\(userId)",
                method: .get,
                queryItems: [
                    URLQueryItem(name: "page", value: String(resolvedPage)),
                    URLQueryItem(name: "size", value: String(resolvedSize))
                ],
                requiresAuthorization: true
            )

            return try await apiClient.request(request, responseType: SubscribeListResponse.self)
        } catch {
            if isRequestCancelled(error) { throw error }
            throw mapError(error)
        }
    }

    func subscribe(to subscribeToUserId: Int) async throws {
        do {
            let request = APIRequest(
                path: "/subscribes/\(subscribeToUserId)",
                method: .post,
                requiresAuthorization: true
            )
            try await apiClient.request(request)
        } catch {
            if isRequestCancelled(error) { throw error }
            throw mapError(error)
        }
    }

    func unsubscribe(from subscribeToUserId: Int) async throws {
        do {
            let request = APIRequest(
                path: "/subscribes/\(subscribeToUserId)",
                method: .delete,
                requiresAuthorization: true
            )
            try await apiClient.request(request)
        } catch {
            if isRequestCancelled(error) { throw error }
            throw mapError(error)
        }
    }

    private func mapError(_ error: Error) -> SubscribeServiceError {
        if let subscribeError = error as? SubscribeServiceError {
            return subscribeError
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

    private func isRequestCancelled(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
