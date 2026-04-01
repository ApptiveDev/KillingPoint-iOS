import Foundation

struct SubscribeUserModel: Decodable, Identifiable {
    let userId: Int
    let username: String
    let tag: String
    let identifier: String
    let profileImageUrl: String
    let userRoleType: String
    let socialType: String
    let isMyPick: Bool?

    private enum CodingKeys: String, CodingKey {
        case userId
        case username
        case tag
        case identifier
        case profileImageUrl
        case userRoleType
        case socialType
        case isMyPick
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(Int.self, forKey: .userId)
        username = try container.decode(String.self, forKey: .username)
        tag = try container.decode(String.self, forKey: .tag)
        identifier = try container.decode(String.self, forKey: .identifier)
        profileImageUrl = try container.decode(String.self, forKey: .profileImageUrl)
        userRoleType = try container.decode(String.self, forKey: .userRoleType)
        socialType = try container.decode(String.self, forKey: .socialType)
        isMyPick = container.decodeFlexibleBoolIfPresent(forKey: .isMyPick)
    }

    var id: Int { userId }

    var displayName: String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "킬링파트 사용자" : trimmed
    }

    var displayTag: String {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "@killingpart_user" }
        return trimmed.hasPrefix("@") ? trimmed : "@\(trimmed)"
    }

    var profileImageURL: URL? {
        resolvedProfileImageURL(from: profileImageUrl)
    }
}

struct SubscribePageModel: Decodable {
    let size: Int
    let number: Int
    let totalElements: Int
    let totalPages: Int
}

struct SubscribeListResponse: Decodable {
    let content: [SubscribeUserModel]
    let page: SubscribePageModel
}

private extension KeyedDecodingContainer {
    func decodeFlexibleBoolIfPresent(forKey key: K) -> Bool? {
        if let boolValue = try? decodeIfPresent(Bool.self, forKey: key) {
            return boolValue
        }

        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            let normalized = stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalized == "true" { return true }
            if normalized == "false" { return false }
        }

        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return intValue != 0
        }

        return nil
    }
}
