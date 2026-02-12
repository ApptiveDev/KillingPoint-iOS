import Foundation

protocol AuthenticationServicing {
    func login(email: String, password: String) async -> Bool
    func loginWithKakao(accessToken: String) async throws -> KakaoSocialLoginResponse
}

enum AuthenticationServiceError: LocalizedError {
    case invalidKakaoAccessToken
    case invalidResponse
    case serverError(statusCode: Int, message: String?)
    case decodingFailed
    case requestEncodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidKakaoAccessToken:
            return "카카오 액세스 토큰이 유효하지 않아요."
        case .invalidResponse:
            return "서버 응답을 확인할 수 없어요."
        case .serverError(let statusCode, let message):
            if let message, !message.isEmpty {
                print("로그인 처리에 실패했어요. (status: \(statusCode), message: \(message))")
                return "로그인 처리에 실패했어요."
            }
            print("로그인 처리에 실패했어요. (status: \(statusCode)")
            return "로그인 처리에 실패했어요."
        case .decodingFailed:
            return "로그인 응답 파싱에 실패했어요."
        case .requestEncodingFailed:
            return "로그인 요청 생성에 실패했어요."
        }
    }
}

struct AuthenticationService: AuthenticationServicing {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func login(email: String, password: String) async -> Bool {
        try? await Task.sleep(for: .milliseconds(600))
        return !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func loginWithKakao(accessToken: String) async throws -> KakaoSocialLoginResponse {
        let trimmedToken = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            throw AuthenticationServiceError.invalidKakaoAccessToken
        }

        var request = URLRequest(url: APIConfiguration.endpoint(path: "/oauth2/kakao"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            request.httpBody = try JSONEncoder().encode(
                KakaoSocialLoginRequest(accessToken: trimmedToken)
            )
        } catch {
            throw AuthenticationServiceError.requestEncodingFailed
        }

        debugLogOutgoingRequest(request)
        let (data, response) = try await session.data(for: request)
        debugLogIncomingResponse(response, data: data)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticationServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let responseMessage = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw AuthenticationServiceError.serverError(
                statusCode: httpResponse.statusCode,
                message: responseMessage
            )
        }

        do {
            return try JSONDecoder().decode(KakaoSocialLoginResponse.self, from: data)
        } catch {
            throw AuthenticationServiceError.decodingFailed
        }
    }

    private func debugLogOutgoingRequest(_ request: URLRequest) {
        #if DEBUG
        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url?.absoluteString ?? "nil"
        let headers = request.allHTTPHeaderFields ?? [:]
        let bodyString = request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"

        print(
            """
            [Network][Request]
            method: \(method)
            url: \(url)
            headers: \(headers)
            body: \(bodyString)
            """
        )
        #endif
    }

    private func debugLogIncomingResponse(_ response: URLResponse?, data: Data) {
        #if DEBUG
        if let httpResponse = response as? HTTPURLResponse {
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
            return
        }

        print("[Network][Response] invalid response: \(String(describing: response))")
        #endif
    }
}
