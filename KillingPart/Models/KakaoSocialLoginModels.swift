import Foundation

struct KakaoSocialLoginRequest: Encodable {
    let accessToken: String
}

struct KakaoSocialLoginResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let isNew: Bool
}
