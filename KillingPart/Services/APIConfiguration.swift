import Foundation

enum APIConfiguration {
    static let baseURL: URL = resolveURL(forInfoDictionaryKey: "BASE_URL")
    static let musicBaseURL: URL = resolveURL(forInfoDictionaryKey: "MUSIC_BASE_URL")

    static func endpoint(path: String, queryItems: [URLQueryItem] = []) -> URL {
        endpoint(baseURL: baseURL, path: path, queryItems: queryItems)
    }

    static func endpoint(baseURL: URL, path: String, queryItems: [URLQueryItem] = []) -> URL {
        let components = path.split(separator: "/").map(String.init)
        let urlWithPath = components.reduce(baseURL) { partialURL, component in
            partialURL.appendingPathComponent(component)
        }

        guard !queryItems.isEmpty else {
            return urlWithPath
        }

        guard var urlComponents = URLComponents(url: urlWithPath, resolvingAgainstBaseURL: false) else {
            return urlWithPath
        }

        urlComponents.queryItems = queryItems
        return urlComponents.url ?? urlWithPath
    }

    private static func resolveURL(forInfoDictionaryKey key: String) -> URL {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: key) as? String,
            let resolvedURL = URL(string: urlString),
            resolvedURL.scheme != nil,
            resolvedURL.host != nil
        else {
            preconditionFailure(
                "\(key) is missing or invalid (\(Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "nil")). Check your xcconfig values."
            )
        }

        return resolvedURL
    }
}
