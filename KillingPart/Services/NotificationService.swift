import Foundation

protocol NotificationServicing {
    func fetchMyNotificationSetting() async throws -> NotificationSettingModel
    func updateMyNotificationSetting(alarmEnabled: Bool) async throws -> NotificationSettingModel
    func fetchAlarmHistory(page: Int, size: Int) async throws -> AlarmHistoryResponse
}

struct NotificationSettingModel {
    let alarmEnabled: Bool
}

struct AlarmHistoryItem: Decodable, Identifiable, Hashable {
    let alarmId: Int
    let title: String
    let content: String
    let deepLink: String
    let createDate: String?

    var id: Int { alarmId }

    private enum CodingKeys: String, CodingKey {
        case alarmId
        case title
        case content
        case deepLink
        case createDate
        case createdDate
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let intValue = try? container.decode(Int.self, forKey: .alarmId) {
            alarmId = intValue
        } else if
            let stringValue = try? container.decode(String.self, forKey: .alarmId),
            let intValue = Int(stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        {
            alarmId = intValue
        } else {
            alarmId = 0
        }

        title = (try? container.decode(String.self, forKey: .title)) ?? ""
        content = (try? container.decode(String.self, forKey: .content)) ?? ""
        deepLink = (try? container.decode(String.self, forKey: .deepLink)) ?? ""

        if let createDateValue = try? container.decodeIfPresent(String.self, forKey: .createDate), !createDateValue.isEmpty {
            createDate = createDateValue
        } else if let createdDateValue = try? container.decodeIfPresent(String.self, forKey: .createdDate), !createdDateValue.isEmpty {
            createDate = createdDateValue
        } else if let createdAtValue = try? container.decodeIfPresent(String.self, forKey: .createdAt), !createdAtValue.isEmpty {
            createDate = createdAtValue
        } else {
            createDate = nil
        }
    }
}

struct AlarmHistoryPage: Decodable {
    let size: Int
    let number: Int
    let totalElements: Int
    let totalPages: Int
}

struct AlarmHistoryResponse: Decodable {
    let content: [AlarmHistoryItem]
    let page: AlarmHistoryPage
}

enum NotificationServiceError: LocalizedError {
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
            return message ?? "알림 설정 변경에 실패했어요."
        case .requestEncodingFailed:
            return "요청 생성에 실패했어요."
        case .sessionExpired:
            return "세션이 만료되었어요. 다시 로그인해 주세요."
        case .networkFailure(let message):
            return message
        }
    }
}

struct NotificationService: NotificationServicing {
    private let apiClient: APIClienting

    init(apiClient: APIClienting = APIClient.shared) {
        self.apiClient = apiClient
    }

    func fetchAlarmHistory(page: Int, size: Int) async throws -> AlarmHistoryResponse {
        do {
            let request = APIRequest(
                path: "/alarms",
                method: .get,
                queryItems: [
                    URLQueryItem(name: "page", value: "\(max(page, 0))"),
                    URLQueryItem(name: "size", value: "\(max(size, 1))")
                ],
                requiresAuthorization: true
            )
            return try await apiClient.request(request, responseType: AlarmHistoryResponse.self)
        } catch {
            if isRequestCancelled(error) { throw error }
            throw mapError(error)
        }
    }

    func fetchMyNotificationSetting() async throws -> NotificationSettingModel {
        do {
            let request = APIRequest(
                path: "/users/my/notification-settings",
                method: .get,
                requiresAuthorization: true
            )
            let response = try await apiClient.request(request, responseType: NotificationSettingResponse.self)
            return NotificationSettingModel(alarmEnabled: response.alarmEnabled)
        } catch {
            if isRequestCancelled(error) { throw error }
            throw mapError(error)
        }
    }

    func updateMyNotificationSetting(alarmEnabled: Bool) async throws -> NotificationSettingModel {
        let requestBody: Data
        do {
            requestBody = try JSONEncoder().encode(NotificationSettingRequest(alarmEnabled: alarmEnabled))
        } catch {
            throw NotificationServiceError.requestEncodingFailed
        }

        do {
            var request = APIRequest(
                path: "/users/my/notification-settings",
                method: .patch,
                requiresAuthorization: true,
                body: requestBody
            )
            request.headers["Accept"] = "application/json"
            request.headers["Content-Type"] = "application/json"
            let response = try await apiClient.request(request, responseType: NotificationSettingResponse.self)
            return NotificationSettingModel(alarmEnabled: response.alarmEnabled)
        } catch {
            if isRequestCancelled(error) { throw error }
            throw mapError(error)
        }
    }

    private func mapError(_ error: Error) -> NotificationServiceError {
        if let serviceError = error as? NotificationServiceError {
            return serviceError
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
                return .invalidResponse
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

private struct NotificationSettingRequest: Encodable {
    let alarmEnabled: Bool
}

private struct NotificationSettingResponse: Decodable {
    let alarmEnabled: Bool
}
