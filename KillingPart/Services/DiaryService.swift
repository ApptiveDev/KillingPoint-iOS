import Foundation

protocol DiaryServicing {
    func fetchMyFeeds(page: Int, size: Int) async throws -> MyDiaryFeedsResponse
    func createDiary(request: DiaryCreateRequest) async throws -> DiaryCreateResult
    func updateDiary(diaryId: Int, request: DiaryUpdateRequest) async throws
    func deleteDiary(diaryId: Int) async throws
}

enum DiaryServiceError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int, message: String?)
    case decodingFailed
    case requestEncodingFailed
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
        case .requestEncodingFailed:
            return "요청 생성에 실패했어요."
        case .sessionExpired:
            return "세션이 만료되었어요. 다시 로그인해 주세요."
        case .networkFailure(let message):
            return message
        }
    }
}

struct DiaryService: DiaryServicing {
    static let defaultPage = 0
    static let defaultSize = 5

    private let apiClient: APIClienting

    init(apiClient: APIClienting = APIClient.shared) {
        self.apiClient = apiClient
    }

    func fetchMyFeeds(
        page: Int = Self.defaultPage,
        size: Int = Self.defaultSize
    ) async throws -> MyDiaryFeedsResponse {
        let resolvedPage = max(page, Self.defaultPage)
        let resolvedSize = size > 0 ? size : Self.defaultSize

        do {
            let request = APIRequest(
                path: "/diaries/my",
                method: .get,
                queryItems: [
                    URLQueryItem(name: "page", value: String(resolvedPage)),
                    URLQueryItem(name: "size", value: String(resolvedSize))
                ],
                requiresAuthorization: true
            )

            return try await apiClient.request(request, responseType: MyDiaryFeedsResponse.self)
        } catch {
            if isRequestCancelled(error) { throw error }
            throw mapError(error)
        }
    }

    func createDiary(request: DiaryCreateRequest) async throws -> DiaryCreateResult {
        let requestBody: Data
        do {
            requestBody = try JSONEncoder().encode(request)
        } catch {
            throw DiaryServiceError.requestEncodingFailed
        }

        do {
            var apiRequest = APIRequest(
                path: "/diaries",
                method: .post,
                requiresAuthorization: true,
                body: requestBody
            )
            apiRequest.headers["Accept"] = "application/json"
            apiRequest.headers["Content-Type"] = "application/json"

            let response = try await apiClient.requestWithResponse(apiRequest)
            let location = response.value(forHTTPHeaderField: "Location")
            return DiaryCreateResult(
                diaryId: extractDiaryID(from: location),
                location: location
            )
        } catch {
            if isRequestCancelled(error) { throw error }
            throw mapError(error)
        }
    }

    func updateDiary(diaryId: Int, request: DiaryUpdateRequest) async throws {
        let requestBody: Data
        do {
            requestBody = try JSONEncoder().encode(request)
        } catch {
            throw DiaryServiceError.requestEncodingFailed
        }

        do {
            var apiRequest = APIRequest(
                path: "/diaries/\(diaryId)",
                method: .put,
                requiresAuthorization: true,
                body: requestBody
            )
            apiRequest.headers["Accept"] = "application/json"
            apiRequest.headers["Content-Type"] = "application/json"
            try await apiClient.request(apiRequest)
        } catch {
            if isRequestCancelled(error) { throw error }
            throw mapError(error)
        }
    }

    func deleteDiary(diaryId: Int) async throws {
        do {
            let request = APIRequest(
                path: "/diaries/\(diaryId)",
                method: .delete,
                requiresAuthorization: true
            )
            try await apiClient.request(request)
        } catch {
            if isRequestCancelled(error) { throw error }
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

    private func extractDiaryID(from location: String?) -> Int? {
        guard let location else { return nil }
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let lastComponent = trimmed.split(separator: "/").last else {
            return nil
        }
        return Int(lastComponent)
    }

    private func isRequestCancelled(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
