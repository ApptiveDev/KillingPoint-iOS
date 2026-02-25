import Foundation

protocol YoutubeServicing {
    func searchVideos(trackID: String, title: String, artist: String) async throws -> [YoutubeVideo]
}

enum YoutubeServiceError: LocalizedError {
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
            return message ?? "유튜브 검색 처리에 실패했어요."
        case .decodingFailed:
            return "유튜브 검색 응답 파싱에 실패했어요."
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

    func searchVideos(trackID: String, title: String, artist: String) async throws -> [YoutubeVideo] {
        let trimmedTrackID = trackID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTrackID.isEmpty, !trimmedTitle.isEmpty else { return [] }

        let query = YoutubeSearchQuery(
            id: trimmedTrackID,
            artist: trimmedArtist,
            title: trimmedTitle
        )

        let request = APIRequest(
            path: "/youtube",
            method: .get,
            queryItems: query.queryItems,
            requiresAuthorization: true,
            body: nil
        )

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
