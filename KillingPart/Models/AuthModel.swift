import Foundation

struct KakaoLoginRequest: Encodable {
    let accessToken: String
}

struct AppleLoginRequest: Encodable {
    let identityToken: String
    let authorizationCode: String
}

struct AuthLoginResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let isNew: Bool
}
