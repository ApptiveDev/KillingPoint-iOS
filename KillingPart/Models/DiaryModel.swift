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
    let isMyPick: Bool?

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

struct DiaryLikeToggleResponse: Decodable {
    let isLiked: Bool
}

struct DiaryStoreToggleResponse: Decodable {
    let isStored: Bool
}

struct MyDiaryFeedsResponse: Decodable {
    let content: [DiaryFeedModel]
    let page: DiaryFeedPageModel
}

struct RandomDiaryFeedsResponse: Decodable {
    let content: [DiaryFeedModel]
    let pageSize: Int

    private enum CodingKeys: String, CodingKey {
        case content
        case pageSize
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decode([DiaryFeedModel].self, forKey: .content)
        pageSize = max(container.decodeFlexibleInt(forKey: .pageSize) ?? content.count, content.count)
    }

    var asMyDiaryFeedsResponse: MyDiaryFeedsResponse {
        MyDiaryFeedsResponse(
            content: content,
            page: DiaryFeedPageModel(
                size: pageSize,
                number: 0,
                totalElements: content.count,
                totalPages: 1
            )
        )
    }
}

struct StoredDiaryFeedModel: Decodable, Identifiable {
    let diaryId: Int
    let artist: String
    let musicTitle: String
    let albumImageUrl: String
    let videoUrl: String
    let originalAuthorTag: String
    let duration: String
    let totalDuration: String
    let start: String
    let end: String

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

    var displayOriginalAuthorTag: String {
        let trimmed = originalAuthorTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "@killingpart_user" }
        return trimmed.hasPrefix("@") ? trimmed : "@\(trimmed)"
    }

    private enum CodingKeys: String, CodingKey {
        case diaryId
        case artist
        case musicTitle
        case albumImageUrl
        case videoUrl
        case originalAuthorTag
        case duration
        case totalDuration
        case start
        case end
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        diaryId = container.decodeFlexibleInt(forKey: .diaryId) ?? 0
        artist = container.decodeFlexibleString(forKey: .artist)
        musicTitle = container.decodeFlexibleString(forKey: .musicTitle)
        albumImageUrl = container.decodeFlexibleString(forKey: .albumImageUrl)
        videoUrl = container.decodeFlexibleString(forKey: .videoUrl)
        originalAuthorTag = container.decodeFlexibleString(forKey: .originalAuthorTag)
        duration = container.decodeFlexibleString(forKey: .duration)
        totalDuration = container.decodeFlexibleString(forKey: .totalDuration)
        start = container.decodeFlexibleString(forKey: .start)
        end = container.decodeFlexibleString(forKey: .end)
    }
}

struct StoredDiaryFeedsResponse: Decodable {
    let content: [StoredDiaryFeedModel]
    let page: DiaryFeedPageModel
}

struct UserDiaryFeedModel: Decodable, Identifiable {
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

    var id: Int { diaryId }

    func toDiaryFeedModel(user: UserModel) -> DiaryFeedModel {
        DiaryFeedModel(
            diaryId: diaryId,
            artist: artist,
            musicTitle: musicTitle,
            albumImageUrl: albumImageUrl,
            content: content,
            videoUrl: videoUrl,
            scope: scope,
            duration: duration,
            totalDuration: totalDuration,
            start: start,
            end: end,
            createDate: createDate,
            updateDate: updateDate,
            isLiked: isLiked,
            isStored: isStored,
            likeCount: likeCount,
            userId: user.userId,
            username: user.username,
            tag: user.tag,
            profileImageUrl: user.profileImageUrl,
            isMyPick: user.isMyPick
        )
    }
}

struct UserDiaryFeedsResponse: Decodable {
    let content: [UserDiaryFeedModel]
    let page: DiaryFeedPageModel
}

private extension KeyedDecodingContainer {
    func decodeFlexibleString(forKey key: K) -> String {
        if let value = try? decode(String.self, forKey: key) {
            return value
        }

        if let value = try? decode(Int.self, forKey: key) {
            return String(value)
        }

        if let value = try? decode(Double.self, forKey: key) {
            return String(value)
        }

        if let value = try? decode(Bool.self, forKey: key) {
            return value ? "true" : "false"
        }

        return ""
    }

    func decodeFlexibleInt(forKey key: K) -> Int? {
        if let value = try? decode(Int.self, forKey: key) {
            return value
        }

        if let value = try? decode(String.self, forKey: key) {
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        if let value = try? decode(Double.self, forKey: key) {
            return Int(value)
        }

        return nil
    }
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

struct DiaryReportRequest: Encodable {
    let content: String
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

struct DiaryOrderUpdateRequest: Encodable {
    let diaryIds: [Int]
}

struct MyCalendarDiariesResponse: Decodable {
    let diariesByDate: [String: [DiaryFeedModel]]

    var diaries: [DiaryFeedModel] {
        diariesByDate.values.flatMap { $0 }
    }

    init(diariesByDate: [String: [DiaryFeedModel]]) {
        self.diariesByDate = Self.normalized(diariesByDate: diariesByDate)
    }

    init(from decoder: Decoder) throws {
        if let feeds = try? [CalendarDiaryFeedResponse](from: decoder) {
            self.diariesByDate = Self.groupedByDate(from: feeds)
            return
        }

        if let keyedFeeds = try? [String: [CalendarDiaryFeedResponse]](from: decoder) {
            self.diariesByDate = Self.normalized(diariesByDate: keyedFeeds)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let feeds = container.decodeCalendarDiaryFeedArray() {
            self.diariesByDate = Self.groupedByDate(from: feeds)
            return
        }

        if let groups = container.decodeCalendarGroups() {
            self.diariesByDate = Self.groupedByDate(from: groups)
            return
        }

        if let dataContainer = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .data) {
            if let feeds = dataContainer.decodeCalendarDiaryFeedArray() {
                self.diariesByDate = Self.groupedByDate(from: feeds)
                return
            }

            if let groups = dataContainer.decodeCalendarGroups() {
                self.diariesByDate = Self.groupedByDate(from: groups)
                return
            }
        }

        self.diariesByDate = [:]
    }

    enum CodingKeys: String, CodingKey {
        case content
        case diaries
        case data
        case items
        case list
        case result
        case calendar
        case dates
    }

    private static func groupedByDate(from feeds: [CalendarDiaryFeedResponse]) -> [String: [DiaryFeedModel]] {
        var grouped: [String: [DiaryFeedModel]] = [:]
        for feed in feeds {
            let key = feed.calendarDateKey
            guard !key.isEmpty else { continue }
            grouped[key, default: []].append(feed.toDiaryFeedModel())
        }
        return grouped
    }

    private static func groupedByDate(from groups: [CalendarDiaryGroupPayload]) -> [String: [DiaryFeedModel]] {
        var grouped: [String: [DiaryFeedModel]] = [:]
        for group in groups {
            let normalizedDate = normalizeDateKey(group.date)
            guard !normalizedDate.isEmpty else { continue }
            grouped[normalizedDate, default: []].append(contentsOf: group.diaries.map { $0.toDiaryFeedModel() })
        }
        return grouped
    }

    private static func normalized(diariesByDate: [String: [DiaryFeedModel]]) -> [String: [DiaryFeedModel]] {
        var normalized: [String: [DiaryFeedModel]] = [:]
        for (rawKey, diaries) in diariesByDate {
            let key = normalizeDateKey(rawKey)
            guard !key.isEmpty else { continue }
            normalized[key, default: []].append(contentsOf: diaries)
        }
        return normalized
    }

    private static func normalized(diariesByDate: [String: [CalendarDiaryFeedResponse]]) -> [String: [DiaryFeedModel]] {
        var normalized: [String: [DiaryFeedModel]] = [:]
        for (rawKey, diaries) in diariesByDate {
            let key = normalizeDateKey(rawKey)
            guard !key.isEmpty else { continue }
            normalized[key, default: []].append(contentsOf: diaries.map { $0.toDiaryFeedModel() })
        }
        return normalized
    }

    private static func normalizeDateKey(_ rawDate: String) -> String {
        let trimmed = rawDate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return trimmed.split(separator: "T").first.map(String.init) ?? trimmed
    }
}

private extension KeyedDecodingContainer<MyCalendarDiariesResponse.CodingKeys> {
    func decodeCalendarDiaryFeedArray() -> [CalendarDiaryFeedResponse]? {
        if let value = try? decode([CalendarDiaryFeedResponse].self, forKey: .content) { return value }
        if let value = try? decode([CalendarDiaryFeedResponse].self, forKey: .diaries) { return value }
        if let value = try? decode([CalendarDiaryFeedResponse].self, forKey: .items) { return value }
        if let value = try? decode([CalendarDiaryFeedResponse].self, forKey: .list) { return value }
        if let value = try? decode([CalendarDiaryFeedResponse].self, forKey: .result) { return value }
        return nil
    }

    func decodeCalendarGroups() -> [CalendarDiaryGroupPayload]? {
        if let value = try? decode([CalendarDiaryGroupPayload].self, forKey: .content) { return value }
        if let value = try? decode([CalendarDiaryGroupPayload].self, forKey: .data) { return value }
        if let value = try? decode([CalendarDiaryGroupPayload].self, forKey: .diaries) { return value }
        if let value = try? decode([CalendarDiaryGroupPayload].self, forKey: .items) { return value }
        if let value = try? decode([CalendarDiaryGroupPayload].self, forKey: .list) { return value }
        if let value = try? decode([CalendarDiaryGroupPayload].self, forKey: .calendar) { return value }
        if let value = try? decode([CalendarDiaryGroupPayload].self, forKey: .dates) { return value }
        return nil
    }
}

private struct CalendarDiaryGroupPayload: Decodable {
    let date: String
    let diaries: [CalendarDiaryFeedResponse]

    private enum CodingKeys: String, CodingKey {
        case date
        case day
        case diaryDate
        case targetDate
        case content
        case diaries
        case items
        case list
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        date = (try? container.decode(String.self, forKey: .date))
            ?? (try? container.decode(String.self, forKey: .day))
            ?? (try? container.decode(String.self, forKey: .diaryDate))
            ?? (try? container.decode(String.self, forKey: .targetDate))
            ?? ""

        diaries = (try? container.decode([CalendarDiaryFeedResponse].self, forKey: .diaries))
            ?? (try? container.decode([CalendarDiaryFeedResponse].self, forKey: .content))
            ?? (try? container.decode([CalendarDiaryFeedResponse].self, forKey: .items))
            ?? (try? container.decode([CalendarDiaryFeedResponse].self, forKey: .list))
            ?? []
    }
}

private struct CalendarDiaryFeedResponse: Decodable {
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

    private enum CodingKeys: String, CodingKey {
        case diaryId
        case artist
        case musicTitle
        case albumImageUrl
        case content
        case videoUrl
        case scope
        case duration
        case totalDuration
        case start
        case end
        case createDate
        case updateDate
    }

    var calendarDateKey: String {
        let created = Self.normalizedDateKey(from: createDate)
        if !created.isEmpty { return created }
        return Self.normalizedDateKey(from: updateDate)
    }

    func toDiaryFeedModel() -> DiaryFeedModel {
        DiaryFeedModel(
            diaryId: diaryId,
            artist: artist,
            musicTitle: musicTitle,
            albumImageUrl: albumImageUrl,
            content: content,
            videoUrl: videoUrl,
            scope: scope,
            duration: duration,
            totalDuration: totalDuration,
            start: start,
            end: end,
            createDate: createDate,
            updateDate: updateDate,
            isLiked: false,
            isStored: false,
            likeCount: 0,
            userId: 0,
            username: nil,
            tag: nil,
            profileImageUrl: nil,
            isMyPick: nil
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        diaryId = (try? container.decode(Int.self, forKey: .diaryId))
            ?? Int((try? container.decode(String.self, forKey: .diaryId)) ?? "")
            ?? 0
        artist = (try? container.decode(String.self, forKey: .artist)) ?? ""
        musicTitle = (try? container.decode(String.self, forKey: .musicTitle)) ?? ""
        albumImageUrl = (try? container.decode(String.self, forKey: .albumImageUrl)) ?? ""
        content = (try? container.decode(String.self, forKey: .content)) ?? ""
        videoUrl = (try? container.decode(String.self, forKey: .videoUrl)) ?? ""
        scope = (try? container.decode(DiaryScope.self, forKey: .scope)) ?? .private
        duration = (try? container.decode(String.self, forKey: .duration)) ?? ""
        totalDuration = (try? container.decode(String.self, forKey: .totalDuration)) ?? ""
        start = (try? container.decode(String.self, forKey: .start)) ?? ""
        end = (try? container.decode(String.self, forKey: .end)) ?? ""
        createDate = (try? container.decode(String.self, forKey: .createDate)) ?? ""
        updateDate = (try? container.decode(String.self, forKey: .updateDate)) ?? ""
    }

    private static func normalizedDateKey(from rawDate: String) -> String {
        let trimmed = rawDate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return trimmed.split(separator: "T").first.map(String.init) ?? trimmed
    }
}

extension DiaryFeedModel {
    var calendarDateKey: String {
        let created = Self.normalizedDateKey(from: createDate)
        if !created.isEmpty { return created }
        return Self.normalizedDateKey(from: updateDate)
    }

    private static func normalizedDateKey(from rawDate: String) -> String {
        let trimmed = rawDate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return trimmed.split(separator: "T").first.map(String.init) ?? trimmed
    }

    func replacingInteraction(
        isLiked: Bool? = nil,
        isStored: Bool? = nil,
        likeCount: Int? = nil
    ) -> DiaryFeedModel {
        DiaryFeedModel(
            diaryId: diaryId,
            artist: artist,
            musicTitle: musicTitle,
            albumImageUrl: albumImageUrl,
            content: content,
            videoUrl: videoUrl,
            scope: scope,
            duration: duration,
            totalDuration: totalDuration,
            start: start,
            end: end,
            createDate: createDate,
            updateDate: updateDate,
            isLiked: isLiked ?? self.isLiked,
            isStored: isStored ?? self.isStored,
            likeCount: likeCount ?? self.likeCount,
            userId: userId,
            username: username,
            tag: tag,
            profileImageUrl: profileImageUrl,
            isMyPick: isMyPick
        )
    }

    func replacingContent(_ content: String) -> DiaryFeedModel {
        DiaryFeedModel(
            diaryId: diaryId,
            artist: artist,
            musicTitle: musicTitle,
            albumImageUrl: albumImageUrl,
            content: content,
            videoUrl: videoUrl,
            scope: scope,
            duration: duration,
            totalDuration: totalDuration,
            start: start,
            end: end,
            createDate: createDate,
            updateDate: updateDate,
            isLiked: isLiked,
            isStored: isStored,
            likeCount: likeCount,
            userId: userId,
            username: username,
            tag: tag,
            profileImageUrl: profileImageUrl,
            isMyPick: isMyPick
        )
    }
}
