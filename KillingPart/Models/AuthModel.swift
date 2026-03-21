import Foundation

struct KakaoLoginRequest: Encodable {
    let accessToken: String
}

struct AppleLoginRequest: Encodable {
    let identityToken: String
    let authorizationCode: String
    let email: String?
    let name: String?

    enum CodingKeys: String, CodingKey {
        case identityToken
        case authorizationCode
        case email
        case name
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identityToken, forKey: .identityToken)
        try container.encode(authorizationCode, forKey: .authorizationCode)

        if let email {
            try container.encode(email, forKey: .email)
        } else {
            try container.encodeNil(forKey: .email)
        }

        if let name {
            try container.encode(name, forKey: .name)
        } else {
            try container.encodeNil(forKey: .name)
        }
    }
}

struct AuthLoginResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let isNew: Bool
}
