import Foundation

enum DiaryScope: String, Codable, CaseIterable, Identifiable {
    case `public` = "PUBLIC"
    case `private` = "PRIVATE"
    case killingPart = "KILLING_PART"

    var id: String { rawValue }

    var addSearchDetailDisplayName: String {
        switch self {
        case .private:
            return "전체 비공개"
        case .killingPart:
            return "킬링파트만 공개"
        case .public:
            return "전체 공개"
        }
    }
}

struct DiaryFeedModel: Decodable, Identifiable {
    let diaryId: Int
    let artist: String
    let musicTitle: String
    let albumImageUrl: String
    let content: String
    let videoUrl: String
    let scope: DiaryScope
    let duration: String
    let totalDuration: String
    let start: String
    let end: String
    let createDate: String
    let updateDate: String
    let isLiked: Bool
    let isStored: Bool
    let likeCount: Int
    let userId: Int
    let username: String?
    let tag: String?
    let profileImageUrl: String?

    var id: Int { diaryId }

    var albumImageURL: URL? {
        let trimmed = albumImageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
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

struct DiaryFeedPageModel: Decodable {
    let size: Int
    let number: Int
    let totalElements: Int
    let totalPages: Int
}

struct MyDiaryFeedsResponse: Decodable {
    let content: [DiaryFeedModel]
    let page: DiaryFeedPageModel
}

struct DiaryCreateRequest: Encodable {
    let artist: String
    let musicTitle: String
    let albumImageUrl: String
    let videoUrl: String
    let scope: DiaryScope
    let content: String
    let duration: String
    let totalDuration: String
    let start: String
    let end: String
}

struct DiaryCreateResult {
    let diaryId: Int?
    let location: String?
}

struct DiaryUpdateRequest: Encodable {
    var artist: String?
    var musicTitle: String?
    var albumImageUrl: String?
    var videoUrl: String?
    var scope: DiaryScope?
    var content: String?
    var duration: String?
    var totalDuration: String?
    var start: String?
    var end: String?

    enum CodingKeys: String, CodingKey {
        case artist
        case musicTitle
        case albumImageUrl
        case videoUrl
        case scope
        case content
        case duration
        case totalDuration
        case start
        case end
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(artist, forKey: .artist)
        try container.encodeIfPresent(musicTitle, forKey: .musicTitle)
        try container.encodeIfPresent(albumImageUrl, forKey: .albumImageUrl)
        try container.encodeIfPresent(videoUrl, forKey: .videoUrl)
        try container.encodeIfPresent(scope, forKey: .scope)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(totalDuration, forKey: .totalDuration)
        try container.encodeIfPresent(start, forKey: .start)
        try container.encodeIfPresent(end, forKey: .end)
    }
}
