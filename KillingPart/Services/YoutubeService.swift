import Foundation

protocol YoutubeServicing {
    func searchVideos(title: String, artist: String) async throws -> [YoutubeVideo]
}

enum YoutubeServiceError: LocalizedError {
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
            return message ?? "유튜브 검색 처리에 실패했어요."
        case .decodingFailed:
            return "유튜브 검색 응답 파싱에 실패했어요."
        case .requestEncodingFailed:
            return "유튜브 검색 요청 생성에 실패했어요."
        case .sessionExpired:
            return "세션이 만료되었어요. 다시 로그인해 주세요."
        case .networkFailure(let message):
            return message
        }
    }
}

struct YoutubeService: YoutubeServicing {
    private let apiClient: APIClienting

    init(apiClient: APIClienting = APIClient.shared) {
        self.apiClient = apiClient
    }

    func searchVideos(title: String, artist: String) async throws -> [YoutubeVideo] {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return [] }

        let requestBody: Data
        do {
            requestBody = try JSONEncoder().encode(
                YoutubeSearchRequest(
                    title: trimmedTitle,
                    artist: trimmedArtist
                )
            )
        } catch {
            throw YoutubeServiceError.requestEncodingFailed
        }

        var request = APIRequest(
            // MUSIC_BASE_URL already contains "/api", so this resolves to ".../api/youtube/search".
            path: "/youtube/search",
            method: .post,
            requiresAuthorization: true,
            body: requestBody,
            baseURL: APIConfiguration.musicBaseURL
        )
        request.headers["Accept"] = "application/json"
        request.headers["Content-Type"] = "application/json"

        do {
            return try await apiClient.request(request, responseType: [YoutubeVideo].self)
        } catch {
            throw mapError(error)
        }
    }

    private func mapError(_ error: Error) -> YoutubeServiceError {
        if let youtubeError = error as? YoutubeServiceError {
            return youtubeError
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

        return .networkFailure(message: "유튜브 검색 요청 중 네트워크 오류가 발생했어요.")
    }
}
