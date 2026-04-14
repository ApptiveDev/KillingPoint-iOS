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
        let searchVariants = makeSearchVariants(from: trimmedQuery)
        var mergedTracks: [SpotifySimpleTrack] = []
        var dedupeKeys = Set<String>()
        var firstFailure: ITunesServiceError?
        var hasSuccessfulRequest = false

        for variant in searchVariants {
            do {
                let rawItems = try await requestTracks(
                    term: variant.term,
                    limit: requestLimit,
                    country: variant.country,
                    language: variant.language,
                    attribute: variant.attribute
                )
                hasSuccessfulRequest = true

                for item in rawItems {
                    guard let track = mapToSimpleTrack(item) else { continue }
                    let dedupeKey = normalizedTrackIdentity(for: track)
                    guard dedupeKeys.insert(dedupeKey).inserted else { continue }
                    mergedTracks.append(track)
                }

                if mergedTracks.count >= requestLimit {
                    break
                }
            } catch let serviceError as ITunesServiceError {
                if firstFailure == nil {
                    firstFailure = serviceError
                }
            } catch {
                if firstFailure == nil {
                    firstFailure = .networkFailure(message: "iTunes 요청 중 네트워크 오류가 발생했어요.")
                }
            }
        }

        if !hasSuccessfulRequest, let firstFailure {
            throw firstFailure
        }

        guard safeOffset < mergedTracks.count else {
            return []
        }

        return Array(mergedTracks.dropFirst(safeOffset).prefix(safeLimit))
    }

    private func requestTracks(
        term: String,
        limit: Int,
        country: String?,
        language: String?,
        attribute: String?
    ) async throws -> [ITunesTrackItem] {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let country, !country.isEmpty {
            queryItems.append(URLQueryItem(name: "country", value: country))
        }
        if let language, !language.isEmpty {
            queryItems.append(URLQueryItem(name: "lang", value: language))
        }
        if let attribute, !attribute.isEmpty {
            queryItems.append(URLQueryItem(name: "attribute", value: attribute))
        }

        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw ITunesServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.get.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ko-KR,ko;q=0.9,en-US;q=0.8", forHTTPHeaderField: "Accept-Language")

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

            return decoded.results
        } catch let error as ITunesServiceError {
            throw error
        } catch {
            throw ITunesServiceError.networkFailure(message: "iTunes 요청 중 네트워크 오류가 발생했어요.")
        }
    }

    private func makeSearchVariants(from query: String) -> [SearchVariant] {
        let normalized = query
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let compact = normalized.replacingOccurrences(of: " ", with: "")

        let candidateTerms: [String] = compact == normalized
            ? [normalized]
            : [normalized, compact]

        var variants: [SearchVariant] = []
        var seenKeys = Set<String>()

        func appendVariant(
            term: String,
            country: String?,
            language: String?,
            attribute: String?
        ) {
            let key = [
                term.lowercased(),
                country?.lowercased() ?? "",
                language?.lowercased() ?? "",
                attribute?.lowercased() ?? ""
            ].joined(separator: "|")
            guard seenKeys.insert(key).inserted else { return }
            variants.append(
                SearchVariant(
                    term: term,
                    country: country,
                    language: language,
                    attribute: attribute
                )
            )
        }

        for term in candidateTerms {
            appendVariant(term: term, country: "KR", language: "ko_kr", attribute: "songTerm")
            appendVariant(term: term, country: "KR", language: "ko_kr", attribute: nil)
        }

        if let primaryTerm = candidateTerms.first {
            appendVariant(term: primaryTerm, country: nil, language: nil, attribute: nil)
        }

        return variants
    }

    private func normalizedTrackIdentity(for track: SpotifySimpleTrack) -> String {
        "\(normalizedIdentityComponent(track.title))|\(normalizedIdentityComponent(track.artist))"
    }

    private func normalizedIdentityComponent(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
    }

    private struct SearchVariant {
        let term: String
        let country: String?
        let language: String?
        let attribute: String?
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
