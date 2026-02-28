import Foundation

struct UserModel: Decodable {
    let userId: Int
    let username: String
    let tag: String
    let identifier: String
    let profileImageUrl: String
    let userRoleType: String
    let socialType: String

    var profileImageURL: URL? {
        let trimmed = profileImageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let parsed = URL(string: trimmed), parsed.scheme != nil {
            return parsed
        }

        if trimmed.hasPrefix("//"), let parsed = URL(string: "https:\(trimmed)") {
            return parsed
        }

        return URL(string: "https://\(trimmed)")
    }
}

struct UserStaticsModel: Decodable {
    let fanCount: Int
    let pickCount: Int
    let killingPartCount: Int
}
