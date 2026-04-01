import Foundation

struct SubscribeUserModel: Decodable, Identifiable {
    let userId: Int
    let username: String
    let tag: String
    let identifier: String
    let profileImageUrl: String
    let userRoleType: String
    let socialType: String

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
