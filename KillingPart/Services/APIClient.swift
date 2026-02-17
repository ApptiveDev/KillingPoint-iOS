import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

struct APIRequest {
    let path: String
    let method: HTTPMethod
    var queryItems: [URLQueryItem]
    var requiresAuthorization: Bool
    var headers: [String: String]
    var body: Data?

    init(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem] = [],
        requiresAuthorization: Bool = false,
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.requiresAuthorization = requiresAuthorization
        self.headers = headers
        self.body = body
    }
}

protocol APIClienting {
    func request(_ request: APIRequest) async throws
    func request<T: Decodable>(_ request: APIRequest, responseType: T.Type) async throws -> T
}

enum APIClientError: LocalizedError {
    case invalidResponse
    case missingAccessToken
    case missingRefreshToken
    case unauthorized
    case serverError(statusCode: Int, message: String?)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "서버 응답을 확인할 수 없어요."
        case .missingAccessToken, .missingRefreshToken, .unauthorized:
            return "세션이 만료되었어요. 다시 로그인해 주세요."
        case .serverError(_, let message):
            return message ?? "요청 처리에 실패했어요."
        case .decodingFailed:
            return "응답 데이터 파싱에 실패했어요."
        }
    }
}

final class APIClient: APIClienting {
    static let shared = APIClient()

    private let session: URLSession
    private let tokenStore: TokenStoring
    private let decoder = JSONDecoder()

    init(
        session: URLSession = .shared,
        tokenStore: TokenStoring = TokenStore.shared
    ) {
        self.session = session
        self.tokenStore = tokenStore
    }

    func request(_ request: APIRequest) async throws {
        let (data, response) = try await execute(request, allowTokenRefresh: true)
        guard (200..<300).contains(response.statusCode) else {
            throw APIClientError.serverError(
                statusCode: response.statusCode,
                message: responseMessage(from: data)
            )
        }
    }

    func request<T: Decodable>(_ request: APIRequest, responseType: T.Type) async throws -> T {
        let (data, response) = try await execute(request, allowTokenRefresh: true)
        guard (200..<300).contains(response.statusCode) else {
            throw APIClientError.serverError(
                statusCode: response.statusCode,
                message: responseMessage(from: data)
            )
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIClientError.decodingFailed
        }
    }

    private func execute(
        _ request: APIRequest,
        allowTokenRefresh: Bool
    ) async throws -> (Data, HTTPURLResponse) {
        let urlRequest = try buildRequest(from: request)
        let (data, response) = try await performDataTask(with: urlRequest)

        if response.statusCode == 401, request.requiresAuthorization, allowTokenRefresh {
            do {
                try await exchangeRefreshTokenForAccessToken()
                return try await execute(request, allowTokenRefresh: false)
            } catch {
                expireSession()
                throw APIClientError.unauthorized
            }
        }

        return (data, response)
    }

    private func buildRequest(from request: APIRequest) throws -> URLRequest {
        var urlRequest = URLRequest(
            url: APIConfiguration.endpoint(path: request.path, queryItems: request.queryItems)
        )
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body

        var headers = request.headers
        if headers["Accept"] == nil {
            headers["Accept"] = "application/json"
        }
        if request.body != nil, headers["Content-Type"] == nil {
            headers["Content-Type"] = "application/json"
        }

        if request.requiresAuthorization {
            guard
                let accessToken = tokenStore.accessToken?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                !accessToken.isEmpty
            else {
                expireSession()
                throw APIClientError.missingAccessToken
            }
            headers["Authorization"] = "Bearer \(accessToken)"
        }

        for (header, value) in headers {
            urlRequest.setValue(value, forHTTPHeaderField: header)
        }

        return urlRequest
    }

    private func performDataTask(with request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        debugLogOutgoingRequest(request)
        do {
            let (data, response) = try await session.data(for: request)
            debugLogIncomingResponse(response, data: data)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIClientError.invalidResponse
            }

            return (data, httpResponse)
        } catch {
            print("[Network][Error] request failed: \(error.localizedDescription)")
            throw error
        }
    }

    private func exchangeRefreshTokenForAccessToken() async throws {
        guard
            let refreshToken = tokenStore.refreshToken?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !refreshToken.isEmpty
        else {
            throw APIClientError.missingRefreshToken
        }

        let refreshRequest = APIRequest(
            path: "/jwt/exchange",
            method: .post,
            requiresAuthorization: false,
            headers: ["X-Refresh-Token": refreshToken]
        )

        let urlRequest = try buildRequest(from: refreshRequest)
        let (data, response) = try await performDataTask(with: urlRequest)
        guard (200..<300).contains(response.statusCode) else {
            throw APIClientError.serverError(
                statusCode: response.statusCode,
                message: responseMessage(from: data)
            )
        }

        do {
            let exchangeResponse = try decoder.decode(TokenExchangeResponse.self, from: data)
            tokenStore.save(
                accessToken: exchangeResponse.accessToken,
                refreshToken: exchangeResponse.refreshToken
            )
        } catch {
            throw APIClientError.decodingFailed
        }
    }

    private func expireSession() {
        tokenStore.clearTokens()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .authenticationSessionExpired, object: nil)
        }
    }

    private func responseMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        if
            let decoded = try? decoder.decode(APIErrorMessageResponse.self, from: data),
            let message = decoded.message?.trimmingCharacters(in: .whitespacesAndNewlines),
            !message.isEmpty
        {
            return message
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

    private func debugLogOutgoingRequest(_ request: URLRequest) {
        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url?.absoluteString ?? "nil"
        let headers = request.allHTTPHeaderFields ?? [:]
        let safeHeaders = maskedSensitiveHeaders(headers)
        let bodyString = request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"

        print(
            """
            [Network][Request]
            method: \(method)
            url: \(url)
            headers: \(safeHeaders)
            body: \(bodyString)
            """
        )
    }

    private func debugLogIncomingResponse(_ response: URLResponse?, data: Data) {
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[Network][Response] invalid response: \(String(describing: response))")
            return
        }

        let bodyString = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
        print(
            """
            [Network][Response]
            status: \(httpResponse.statusCode)
            url: \(httpResponse.url?.absoluteString ?? "nil")
            headers: \(httpResponse.allHeaderFields)
            body: \(bodyString)
            """
        )
    }

    private func maskedSensitiveHeaders(_ headers: [String: String]) -> [String: String] {
        var masked = headers
        for key in headers.keys {
            if key.caseInsensitiveCompare("Authorization") == .orderedSame,
               let value = headers[key] {
                masked[key] = maskToken(value)
            }

            if key.caseInsensitiveCompare("X-Refresh-Token") == .orderedSame,
               let value = headers[key] {
                masked[key] = maskToken(value)
            }
        }
        return masked
    }

    private func maskToken(_ token: String) -> String {
        if token.count <= 12 {
            return "***"
        }

        let prefix = token.prefix(8)
        let suffix = token.suffix(4)
        return "\(prefix)...\(suffix)"
    }
}

private struct APIErrorMessageResponse: Decodable {
    let message: String?
}
