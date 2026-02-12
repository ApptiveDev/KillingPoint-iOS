import Foundation

enum APIConfiguration {
    static let baseURL: URL = {
        guard
            let baseURLString = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String,
            let baseURL = URL(string: baseURLString)
        else {
            preconditionFailure("BASE_URL is missing or invalid. Check your xcconfig values.")
        }

        return baseURL
    }()

    static func endpoint(path: String) -> URL {
        baseURL.appendingPathComponent(path)
    }
}
