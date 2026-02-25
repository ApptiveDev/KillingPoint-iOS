import Foundation

struct YoutubeSearchQuery {
    let id: String
    let artist: String
    let title: String

    var queryItems: [URLQueryItem] {
        [
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "artist", value: artist),
            URLQueryItem(name: "title", value: title)
        ]
    }
}

struct YoutubeVideo: Identifiable, Decodable, Equatable {
    let id: String
    let title: String
    let duration: Double
    private let urlString: String

    enum CodingKeys: String, CodingKey {
        case title
        case duration
        case url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)

        if let numericDuration = try? container.decode(Double.self, forKey: .duration) {
            duration = numericDuration
        } else {
            let durationText = try container.decode(String.self, forKey: .duration)
            guard let parsedDuration = Self.parseDuration(durationText) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .duration,
                    in: container,
                    debugDescription: "Unsupported duration format: \(durationText)"
                )
            }
            duration = parsedDuration
        }

        urlString = try container.decode(String.self, forKey: .url)
        id = Self.extractVideoID(from: urlString) ?? urlString
    }

    var thumbnailURL: URL? {
        guard let videoID = Self.extractVideoID(from: urlString) ?? fallbackVideoID else {
            return nil
        }
        return URL(string: "https://i.ytimg.com/vi/\(videoID)/hqdefault.jpg")
    }

    var embedURL: URL? {
        if let embedURL = URL(string: urlString) {
            return embedURL
        }
        guard let videoID = Self.extractVideoID(from: id) ?? fallbackVideoID else {
            return nil
        }
        return URL(string: "https://www.youtube.com/embed/\(videoID)?playsinline=1")
    }

    private var fallbackVideoID: String? {
        id.contains("http") ? nil : id
    }

    private static func extractVideoID(from value: String) -> String? {
        guard let components = URLComponents(string: value) else {
            return nil
        }

        let pathComponents = components.path.split(separator: "/").map(String.init)
        if let embedIndex = pathComponents.firstIndex(of: "embed"),
           pathComponents.indices.contains(embedIndex + 1) {
            let candidate = pathComponents[embedIndex + 1]
            if !candidate.isEmpty {
                return candidate
            }
        }

        if let watchVideoID = components.queryItems?.first(where: { $0.name == "v" })?.value,
           !watchVideoID.isEmpty {
            return watchVideoID
        }

        return nil
    }

    private static let durationRegex = try? NSRegularExpression(
        pattern: #"^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?$"#
    )

    private static func parseDuration(_ value: String) -> Double? {
        guard let regex = durationRegex else {
            return nil
        }

        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, options: [], range: range) else {
            return nil
        }

        func component(at index: Int) -> Double {
            let componentRange = match.range(at: index)
            guard
                componentRange.location != NSNotFound,
                let swiftRange = Range(componentRange, in: value),
                let parsed = Double(value[swiftRange])
            else {
                return 0
            }
            return parsed
        }

        return component(at: 1) * 3600 + component(at: 2) * 60 + component(at: 3)
    }
}
