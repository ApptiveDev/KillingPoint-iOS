import Foundation

// MARK: - Response

struct CommentResponse: Decodable, Identifiable, Equatable {
    let commentId: Int
    let diaryId: Int
    let parentCommentId: Int?
    var status: String
    let isBlocked: Bool
    var text: String?
    var attachment: CommentAttachment
    var author: CommentAuthor?
    var isMine: Bool
    var isLiked: Bool
    var likeCount: Int
    var replyCount: Int
    let createDate: String
    var isEdited: Bool

    var id: Int { commentId }
    var isDeleted: Bool { status == "DELETED" }
    var isReply: Bool { parentCommentId != nil }

    /// 답글이 남아 있는 원댓글 삭제 시 서버와 같은 형태의 플레이스홀더로 바꾼다
    func asDeletedPlaceholder() -> CommentResponse {
        var copy = self
        copy.status = "DELETED"
        copy.text = nil
        copy.attachment = CommentAttachment(references: [])
        copy.author = nil
        copy.isMine = false
        copy.isLiked = false
        copy.likeCount = 0
        return copy
    }
}

struct CommentAttachment: Decodable, Equatable {
    let references: [CommentReference]
}

struct CommentReference: Decodable, Equatable {
    let targetType: String
    let targetId: Int
    let atOrders: [Int]
    let len: Int
    let display: CommentAuthor?
}

struct CommentAuthor: Decodable, Equatable {
    let userId: Int
    let username: String?
    let tag: String?
    let profileImageUrl: String?
}

struct CommentListResponse: Decodable {
    let commentCount: Int
    let comments: CommentPageResponse
}

struct CommentPageResponse: Decodable {
    let content: [CommentResponse]
    let page: DiaryFeedPageModel
}

struct CommentLikeToggleResponse: Decodable {
    let isLiked: Bool
    let likeCount: Int
}

// MARK: - Request

struct CommentWriteRequest: Encodable {
    let text: String
    let parentCommentId: Int?
    let references: [CommentReferenceRequest]?
}

struct CommentReferenceRequest: Encodable, Equatable {
    var targetType = "USER"
    let targetId: Int
    let atOrders: [Int]
    let len: Int
}

struct CommentReportRequest: Encodable {
    let content: String
}

// MARK: - 멘션 (위치/길이는 UTF-16 기준)

struct CommentMentionCandidate: Equatable {
    let userId: Int
    let name: String
}

enum CommentMention {
    /// 본문의 `@` 순서(1부터)와 그 위치(UTF-16 offset)
    static func atOffsets(in text: String) -> [Int] {
        let at = "@".utf16.first!
        return text.utf16.enumerated().compactMap { $0.element == at ? $0.offset : nil }
    }

    /// 본문에서 `@이름` 이 실제로 남아 있는 후보만 references 로 만든다.
    /// 지워졌거나 바뀐 멘션은 자동으로 빠지므로 서버 400(멘션 불일치)을 막는다.
    static func references(in text: String, candidates: [CommentMentionCandidate]) -> [CommentReferenceRequest] {
        let units = Array(text.utf16)
        // 이름이 겹치면(김기 / 김기영) 긴 이름 우선
        let sorted = candidates.sorted { $0.name.utf16.count > $1.name.utf16.count }
        var ordersByUser: [Int: [Int]] = [:]
        var lenByUser: [Int: Int] = [:]

        for (index, offset) in atOffsets(in: text).enumerated() {
            for candidate in sorted {
                let name = Array(candidate.name.utf16)
                let start = offset + 1
                guard !name.isEmpty, start + name.count <= units.count else { continue }
                guard Array(units[start..<(start + name.count)]) == name else { continue }
                // 같은 유저는 하나의 reference 에 atOrders 로 묶인다 (len 은 동일해야 함)
                if let len = lenByUser[candidate.userId], len != name.count { continue }
                ordersByUser[candidate.userId, default: []].append(index + 1)
                lenByUser[candidate.userId] = name.count
                break
            }
        }

        return ordersByUser.keys.sorted().map { userId in
            CommentReferenceRequest(targetId: userId, atOrders: ordersByUser[userId]!, len: lenByUser[userId]!)
        }
    }

    /// 수정 진입 시 기존 references 를 후보로 되돌린다 (멘션 당시 본문 그대로의 이름)
    static func candidates(from comment: CommentResponse) -> [CommentMentionCandidate] {
        guard let text = comment.text else { return [] }
        let units = Array(text.utf16)
        let offsets = atOffsets(in: text)
        return comment.attachment.references.compactMap { reference in
            guard let order = reference.atOrders.first, order >= 1, order <= offsets.count else { return nil }
            let start = offsets[order - 1] + 1
            guard start + reference.len <= units.count else { return nil }
            let name = String(decoding: units[start..<(start + reference.len)], as: UTF16.self)
            return CommentMentionCandidate(userId: reference.targetId, name: name)
        }
    }

    /// 강조할 멘션 범위들 (`@` 포함, UTF-16 NSRange)
    static func highlightRanges(in text: String, references: [CommentReference]) -> [NSRange] {
        let offsets = atOffsets(in: text)
        let total = text.utf16.count
        return references.flatMap { reference in
            reference.atOrders.compactMap { order -> NSRange? in
                guard order >= 1, order <= offsets.count else { return nil }
                let range = NSRange(location: offsets[order - 1], length: reference.len + 1)
                return range.upperBound <= total ? range : nil
            }
        }
    }
}

// MARK: - 상대 시간 (com_002)

enum CommentTimeFormatter {
    private static let formatters: [DateFormatter] = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm:ss"
    ].map { format in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = format
        return formatter
    }

    static func date(from raw: String) -> Date? {
        formatters.lazy.compactMap { $0.date(from: raw) }.first
    }

    /// ~3분: 방금 / ~59분: n분 / ~23시간: n시간 / 이후: n일
    static func relativeText(from raw: String, now: Date = Date()) -> String {
        guard let date = date(from: raw) else { return "" }
        let minutes = max(Int(now.timeIntervalSince(date) / 60), 0)
        if minutes < 3 { return "방금" }
        if minutes < 60 { return "\(minutes)분" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)시간" }
        return "\(hours / 24)일"
    }
}
