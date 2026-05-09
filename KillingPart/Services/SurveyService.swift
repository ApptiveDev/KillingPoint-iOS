import Foundation

protocol SurveyServicing {
    func submitSurvey(content: String) async throws
}

enum SurveyServiceError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int, message: String?)
    case requestEncodingFailed
    case sessionExpired
    case networkFailure(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "서버 응답을 확인할 수 없어요."
        case .serverError(_, let message):
            return message ?? "문의 전송에 실패했어요."
        case .requestEncodingFailed:
            return "요청 생성에 실패했어요."
        case .sessionExpired:
            return "세션이 만료되었어요. 다시 로그인해 주세요."
        case .networkFailure(let message):
            return message
        }
    }
}

struct SurveyService: SurveyServicing {
    private let apiClient: APIClienting

    init(apiClient: APIClienting = APIClient.shared) {
        self.apiClient = apiClient
    }

    func submitSurvey(content: String) async throws {
        let requestBody: Data
        do {
            requestBody = try JSONEncoder().encode(SurveyRequest(content: content))
        } catch {
            throw SurveyServiceError.requestEncodingFailed
        }

        do {
            var request = APIRequest(
                path: "/surveys",
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

    private func mapError(_ error: Error) -> SurveyServiceError {
        if let surveyError = error as? SurveyServiceError {
            return surveyError
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
                return .invalidResponse
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
            let parsed = try? JSONDecoder().decode(SurveyServiceErrorResponse.self, from: data)
        else {
            return rawMessage
        }

        if let message = parsed.message?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
            return message
        }

        let fieldMessages = (parsed.fieldErrors ?? [])
            .flatMap(\.values)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let globalMessages = (parsed.globalErrors ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let merged = Array(Set(fieldMessages + globalMessages)).sorted()
        guard !merged.isEmpty else { return rawMessage }
        return merged.joined(separator: "\n")
    }

    private func isRequestCancelled(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}

private struct SurveyRequest: Encodable {
    let content: String
}

private struct SurveyServiceErrorResponse: Decodable {
    let message: String?
    let fieldErrors: [[String: String]]?
    let globalErrors: [String]?
}
