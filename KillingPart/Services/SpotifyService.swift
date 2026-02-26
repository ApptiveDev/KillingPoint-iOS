import Foundation

protocol SpotifyServicing {
    func searchTracks(query: String, limit: Int, offset: Int) async throws -> [SpotifySimpleTrack]
}

enum SpotifyServiceError: LocalizedError {
    case missingBasicAuth
    case invalidResponse
    case unauthorized
    case serverError(statusCode: Int, message: String?)
    case decodingFailed
    case networkFailure(message: String)

    var errorDescription: String? {
        switch self {
        case .missingBasicAuth:
            return "Spotify 인증 설정이 누락되었어요."
        case .invalidResponse:
            return "Spotify 응답을 확인할 수 없어요."
        case .unauthorized:
            return "Spotify 인증에 실패했어요. 잠시 후 다시 시도해 주세요."
        case .serverError(_, let message):
            return message ?? "Spotify 검색 처리에 실패했어요."
        case .decodingFailed:
            return "Spotify 응답 파싱에 실패했어요."
        case .networkFailure(let message):
            return message
        }
    }
}

struct SpotifyService: SpotifyServicing {
    private static let tokenCache = SpotifyTokenCache()

    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchTracks(query: String, limit: Int = 5, offset: Int = 0) async throws -> [SpotifySimpleTrack] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        let safeOffset = max(offset, 0)

        let token = try await fetchAccessToken(forceRefresh: false)
        do {
            return try await searchTracksWithBearerToken(
                trimmedQuery,
                limit: limit,
                offset: safeOffset,
                bearerToken: token
            )
        } catch let error as SpotifyServiceError {
            guard case .unauthorized = error else {
                throw error
            }
        } catch {
            throw mapError(error)
        }

        let refreshedToken = try await fetchAccessToken(forceRefresh: true)
        return try await searchTracksWithBearerToken(
            trimmedQuery,
            limit: limit,
            offset: safeOffset,
            bearerToken: refreshedToken
        )
    }

    private func searchTracksWithBearerToken(
        _ query: String,
        limit: Int,
        offset: Int,
        bearerToken: String
    ) async throws -> [SpotifySimpleTrack] {
        var components = URLComponents(string: "https://api.spotify.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "track"),
            URLQueryItem(name: "market", value: "KR"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        guard let url = components?.url else {
            throw SpotifyServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.get.rawValue
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("ko-KR", forHTTPHeaderField: "Accept-Language")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await performDataTask(with: request)
        switch response.statusCode {
        case 200..<300:
            let decoded: SpotifySearchResponse
            do {
                decoded = try decoder.decode(SpotifySearchResponse.self, from: data)
            } catch {
                throw SpotifyServiceError.decodingFailed
            }

            return decoded.tracks.items.map { item in
                let artistNames = item.artists.map(\.name).joined(separator: ", ")

                return SpotifySimpleTrack(
                    id: item.id,
                    title: item.name,
                    artist: artistNames.isEmpty ? "Unknown Artist" : artistNames,
                    albumImageUrl: item.album.images.sorted { (lhs, rhs) in
                        (lhs.width ?? 0) > (rhs.width ?? 0)
                    }.first?.url,
                    albumId: item.album.id
                )
            }
        case 401:
            await Self.tokenCache.clear()
            throw SpotifyServiceError.unauthorized
        default:
            throw SpotifyServiceError.serverError(
                statusCode: response.statusCode,
                message: responseMessage(from: data)
            )
        }
    }

    private func fetchAccessToken(forceRefresh: Bool) async throws -> String {
        if !forceRefresh, let cachedToken = await Self.tokenCache.validToken() {
            return cachedToken
        }

        let basicAuth = try spotifyBasicAuth()
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else {
            throw SpotifyServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(basicAuth, forHTTPHeaderField: "Authorization")
        request.httpBody = "grant_type=client_credentials".data(using: .utf8)

        let (data, response) = try await performDataTask(with: request)
        switch response.statusCode {
        case 200..<300:
            let decoded: SpotifyTokenResponse
            do {
                decoded = try decoder.decode(SpotifyTokenResponse.self, from: data)
            } catch {
                throw SpotifyServiceError.decodingFailed
            }
            await Self.tokenCache.save(
                token: decoded.accessToken,
                expiresIn: decoded.expiresIn
            )
            return decoded.accessToken
        case 401:
            await Self.tokenCache.clear()
            throw SpotifyServiceError.unauthorized
        default:
            throw SpotifyServiceError.serverError(
                statusCode: response.statusCode,
                message: responseMessage(from: data)
            )
        }
    }

    private func spotifyBasicAuth() throws -> String {
        let rawValue = (Bundle.main.object(forInfoDictionaryKey: "SPOTIFY_BASIC_AUTH") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawValue.isEmpty, rawValue != "$(SPOTIFY_BASIC_AUTH)" else {
            throw SpotifyServiceError.missingBasicAuth
        }
        return rawValue
    }

    private func performDataTask(with request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SpotifyServiceError.invalidResponse
            }
            return (data, httpResponse)
        } catch {
            throw mapError(error)
        }
    }

    private func mapError(_ error: Error) -> SpotifyServiceError {
        if let spotifyError = error as? SpotifyServiceError {
            return spotifyError
        }
        return .networkFailure(message: "Spotify 요청 중 네트워크 오류가 발생했어요.")
    }

    private func responseMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        if
            let decodedError = try? decoder.decode(SpotifyTopLevelErrorResponse.self, from: data),
            let message = decodedError.error?.message?.trimmingCharacters(in: .whitespacesAndNewlines),
            !message.isEmpty
        {
            return message
        }

        if
            let tokenError = try? decoder.decode(SpotifyTokenErrorResponse.self, from: data),
            let description = tokenError.errorDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
            !description.isEmpty
        {
            return description
        }

        if
            let raw = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty
        {
            return raw
        }

        return nil
    }
}

private struct SpotifyTopLevelErrorResponse: Decodable {
    let error: SpotifyMessageError?
}

private struct SpotifyMessageError: Decodable {
    let status: Int?
    let message: String?
}

private struct SpotifyTokenErrorResponse: Decodable {
    let error: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

private actor SpotifyTokenCache {
    private var accessToken: String?
    private var expirationDate: Date?

    func validToken() -> String? {
        guard
            let accessToken,
            let expirationDate,
            Date() < expirationDate
        else {
            return nil
        }
        return accessToken
    }

    func save(token: String, expiresIn: Int) {
        accessToken = token
        expirationDate = Date().addingTimeInterval(TimeInterval(max(expiresIn - 60, 0)))
    }

    func clear() {
        accessToken = nil
        expirationDate = nil
    }
}
