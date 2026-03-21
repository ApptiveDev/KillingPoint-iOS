import Foundation

protocol ITunesServicing {
    func searchTracks(query: String, limit: Int, offset: Int) async throws -> [SpotifySimpleTrack]
}

enum ITunesServiceError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int, message: String?)
    case decodingFailed
    case networkFailure(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "iTunes 응답을 확인할 수 없어요."
        case .serverError(_, let message):
            return message ?? "iTunes 검색 처리에 실패했어요."
        case .decodingFailed:
            return "iTunes 응답 파싱에 실패했어요."
        case .networkFailure(let message):
            return message
        }
    }
}

struct ITunesService: ITunesServicing {
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let maxResultCount = 200

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchTracks(query: String, limit: Int = 10, offset: Int = 0) async throws -> [SpotifySimpleTrack] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        let safeLimit = max(limit, 1)
        let safeOffset = max(offset, 0)
        let requestLimit = min(safeOffset + safeLimit, maxResultCount)

        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: trimmedQuery),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "country", value: "KR"),
            URLQueryItem(name: "lang", value: "ko_kr"),
            URLQueryItem(name: "limit", value: String(requestLimit))
        ]

        guard let url = components?.url else {
            throw ITunesServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.get.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ITunesServiceError.invalidResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw ITunesServiceError.serverError(
                    statusCode: httpResponse.statusCode,
                    message: responseMessage(from: data)
                )
            }

            let decoded: ITunesSearchResponse
            do {
                decoded = try decoder.decode(ITunesSearchResponse.self, from: data)
            } catch {
                throw ITunesServiceError.decodingFailed
            }

            let mappedTracks = decoded.results.compactMap(mapToSimpleTrack)
            guard safeOffset < mappedTracks.count else {
                return []
            }

            return Array(mappedTracks.dropFirst(safeOffset).prefix(safeLimit))
        } catch let error as ITunesServiceError {
            throw error
        } catch {
            throw ITunesServiceError.networkFailure(message: "iTunes 요청 중 네트워크 오류가 발생했어요.")
        }
    }

    private func mapToSimpleTrack(_ item: ITunesTrackItem) -> SpotifySimpleTrack? {
        let title = (item.trackName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = (item.artistName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty, !artist.isEmpty else {
            return nil
        }

        let identifier: String
        if let trackId = item.trackId {
            identifier = String(trackId)
        } else {
            identifier = "\(artist)-\(title)-\(item.collectionId ?? 0)"
        }

        let artworkURL = upgradedArtworkURL(from: item.artworkUrl100)
        let albumID = String(item.collectionId ?? item.trackId ?? 0)

        return SpotifySimpleTrack(
            id: identifier,
            title: title,
            artist: artist,
            albumImageUrl: artworkURL,
            albumId: albumID
        )
    }

    private func upgradedArtworkURL(from rawURL: String?) -> String? {
        guard let rawURL, !rawURL.isEmpty else {
            return nil
        }

        return rawURL
            .replacingOccurrences(of: "100x100bb", with: "600x600bb")
            .replacingOccurrences(of: "100x100-75", with: "600x600-75")
    }

    private func responseMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        guard let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        return text
    }
}
