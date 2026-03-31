import Foundation

struct UserModel: Identifiable {
    let userId: Int
    let username: String
    let tag: String
    let identifier: String
    let profileImageUrl: String
    let userRoleType: String
    let socialType: String
    let isMyPick: Bool?

    init(
        userId: Int,
        username: String,
        tag: String,
        identifier: String,
        profileImageUrl: String,
        userRoleType: String,
        socialType: String,
        isMyPick: Bool? = nil
    ) {
        self.userId = userId
        self.username = username
        self.tag = tag
        self.identifier = identifier
        self.profileImageUrl = profileImageUrl
        self.userRoleType = userRoleType
        self.socialType = socialType
        self.isMyPick = isMyPick
    }

    init(from subscribeUser: SubscribeUserModel) {
        self.init(
            userId: subscribeUser.userId,
            username: subscribeUser.username,
            tag: subscribeUser.tag,
            identifier: subscribeUser.identifier,
            profileImageUrl: subscribeUser.profileImageUrl,
            userRoleType: subscribeUser.userRoleType,
            socialType: subscribeUser.socialType,
            isMyPick: nil
        )
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

struct UserSearchPageModel: Decodable {
    let size: Int
    let number: Int
    let totalElements: Int
    let totalPages: Int
}

struct UserSearchResponse {
    let content: [UserModel]
    let page: UserSearchPageModel
}

struct UserResponseDTO: Decodable {
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

    func toModel() -> UserModel {
        UserModel(
            userId: userId,
            username: username,
            tag: tag,
            identifier: identifier,
            profileImageUrl: profileImageUrl,
            userRoleType: userRoleType,
            socialType: socialType,
            isMyPick: isMyPick
        )
    }
}

struct UserSearchResponseDTO: Decodable {
    let content: [UserResponseDTO]
    let page: UserSearchPageModel

    func toModel() -> UserSearchResponse {
        UserSearchResponse(
            content: content.map { $0.toModel() },
            page: page
        )
    }
}

struct UserStaticsModel: Decodable {
    let fanCount: Int
    let pickCount: Int
    let killingPartCount: Int
}

struct PresignedURLResponse: Decodable {
    let id: Int
    let presignedUrl: String
}

struct UpdateMyProfileImageRequest: Encodable {
    let id: Int
    let presignedUrl: String
}

struct UpdateMyTagRequest: Encodable {
    let tag: String
}

private extension KeyedDecodingContainer {
    func decodeFlexibleBoolIfPresent(forKey key: K) -> Bool? {
        if let boolValue = try? decodeIfPresent(Bool.self, forKey: key) {
            return boolValue
        }

        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            let normalized = stringValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()
            if normalized == "true" { return true }
            if normalized == "false" { return false }
        }

        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return intValue != 0
        }

        return nil
    }
}
