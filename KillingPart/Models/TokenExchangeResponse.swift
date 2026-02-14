import Foundation

struct TokenExchangeResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let isNew: Bool
}
