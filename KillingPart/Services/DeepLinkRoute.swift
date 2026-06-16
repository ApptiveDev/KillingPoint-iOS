import Foundation

struct DeepLinkRequest: Equatable, Hashable, Identifiable {
    let id: UUID
    let route: DeepLinkRoute

    init(route: DeepLinkRoute, id: UUID = UUID()) {
        self.id = id
        self.route = route
    }
}

enum DeepLinkRoute: Equatable, Hashable {
    case socialDiary(diaryId: Int)

    init?(url: URL) {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let scheme = components.scheme?.lowercased()
        else {
            return nil
        }

        let pathComponents: [String]
        switch scheme {
        case "https":
            guard components.host?.lowercased() == DeepLinkURLBuilder.host else {
                return nil
            }
            pathComponents = Self.pathComponents(from: components.path)
        case DeepLinkURLBuilder.customScheme:
            let hostComponents = components.host.map { [$0] } ?? []
            pathComponents = hostComponents + Self.pathComponents(from: components.path)
        default:
            return nil
        }

        guard let route = Self.route(from: pathComponents) else {
            return nil
        }
        self = route
    }

    private static func route(from pathComponents: [String]) -> DeepLinkRoute? {
        guard
            pathComponents.count == 2,
            pathComponents[0].caseInsensitiveCompare("diaries") == .orderedSame,
            let diaryId = Int(pathComponents[1]),
            diaryId > 0
        else {
            return nil
        }

        return .socialDiary(diaryId: diaryId)
    }

    private static func pathComponents(from path: String) -> [String] {
        path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .split(separator: "/")
            .map(String.init)
    }
}

enum DeepLinkURLBuilder {
    static let host = "killingpart.com"
    static let customScheme = "killingpart"

    static func diaryURL(diaryId: Int) -> URL? {
        guard diaryId > 0 else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/diaries/\(diaryId)"
        return components.url
    }

    static func customDiaryURL(diaryId: Int) -> URL? {
        guard diaryId > 0 else { return nil }

        var components = URLComponents()
        components.scheme = customScheme
        components.host = "diaries"
        components.path = "/\(diaryId)"
        return components.url
    }
}
