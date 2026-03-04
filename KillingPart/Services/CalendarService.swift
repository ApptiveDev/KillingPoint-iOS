import Foundation

protocol CalendarServicing {
    func fetchMyCalendarDiaries(startDate: String, endDate: String) async throws -> MyCalendarDiariesResponse
}

enum CalendarServiceError: LocalizedError {
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
            return message ?? "캘린더 데이터를 불러오지 못했어요."
        case .decodingFailed:
            return "캘린더 응답 파싱에 실패했어요."
        case .sessionExpired:
            return "세션이 만료되었어요. 다시 로그인해 주세요."
        case .networkFailure(let message):
            return message
        }
    }
}

struct CalendarService: CalendarServicing {
    private let apiClient: APIClienting

    init(apiClient: APIClienting = APIClient.shared) {
        self.apiClient = apiClient
    }

    func fetchMyCalendarDiaries(startDate: String, endDate: String) async throws -> MyCalendarDiariesResponse {
        let trimmedStartDate = startDate.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEndDate = endDate.trimmingCharacters(in: .whitespacesAndNewlines)

        var queryItems: [URLQueryItem] = []
        if !trimmedStartDate.isEmpty {
            queryItems.append(URLQueryItem(name: "start", value: trimmedStartDate))
        }
        if !trimmedEndDate.isEmpty {
            queryItems.append(URLQueryItem(name: "end", value: trimmedEndDate))
        }

        let request = APIRequest(
            path: "/diaries/my/calendar",
            method: .get,
            queryItems: queryItems,
            requiresAuthorization: true
        )

        do {
            return try await apiClient.request(request, responseType: MyCalendarDiariesResponse.self)
        } catch {
            if isRequestCancelled(error) { throw error }
            throw mapError(error)
        }
    }

    private func mapError(_ error: Error) -> CalendarServiceError {
        if let calendarError = error as? CalendarServiceError {
            return calendarError
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

        return .networkFailure(message: "캘린더 요청 중 오류가 발생했어요.")
    }

    private func isRequestCancelled(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
