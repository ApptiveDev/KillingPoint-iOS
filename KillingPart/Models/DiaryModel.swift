import Foundation

enum DiaryScope: String, Decodable {
    case `public` = "PUBLIC"
    case `private` = "PRIVATE"
    case killingPart = "KILLING_PART"
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
        URL(string: albumImageUrl)
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
