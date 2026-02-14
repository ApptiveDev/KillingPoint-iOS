import Foundation

enum APIConfiguration {
    static let baseURL: URL = {
        guard
            let baseURLString = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String,
            let baseURL = URL(string: baseURLString),
            baseURL.scheme != nil,
            baseURL.host != nil
        else {
            preconditionFailure(
                "BASE_URL is missing or invalid (\(Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String ?? "nil")). Check your xcconfig values."
            )
        }

        return baseURL
    }()

    static func endpoint(path: String) -> URL {
        let components = path.split(separator: "/").map(String.init)
        return components.reduce(baseURL) { partialURL, component in
            partialURL.appendingPathComponent(component)
        }
    }
}
