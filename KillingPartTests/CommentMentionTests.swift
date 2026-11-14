import Foundation
import Testing
@testable import KillingPart

struct CommentMentionTests {
    @Test
    func referencesUseUTF16AndAtOrderIncludingPlainAt() {
        // 이모지(UTF-16 2칸) + 일반 @ 가 섞여도 순서/길이가 맞아야 한다
        let text = "😀 메일@ 보냄 @이진원 좋다 @이진원"
        let refs = CommentMention.references(
            in: text,
            candidates: [CommentMentionCandidate(userId: 3, name: "이진원")]
        )
        #expect(refs == [CommentReferenceRequest(targetId: 3, atOrders: [2, 3], len: 3)])
    }

    @Test
    func removedMentionIsDropped() {
        let refs = CommentMention.references(
            in: "그냥 답글",
            candidates: [CommentMentionCandidate(userId: 5, name: "김기영")]
        )
        #expect(refs.isEmpty)
    }

    @Test
    func longerNameWinsOnPrefixOverlap() {
        let refs = CommentMention.references(
            in: "@김기영 안녕",
            candidates: [
                CommentMentionCandidate(userId: 1, name: "김기"),
                CommentMentionCandidate(userId: 2, name: "김기영")
            ]
        )
        #expect(refs == [CommentReferenceRequest(targetId: 2, atOrders: [1], len: 3)])
    }

    @Test
    func replyPageDecodesWithMissingFieldsAndNoPageObject() throws {
        // attachment/replyCount/isEdited 누락, page 객체 없이 totalPages 최상위
        let json = """
        {"content":[{"commentId":13,"parentCommentId":12,"text":"@김기영 감사","author":{"userId":1,"username":"홍길동"},
          "attachment":{"references":[{"targetType":"USER","targetId":5,"atOrders":[1],"len":3},{"bad":true}]}}],
         "totalPages":1}
        """
        let page = try JSONDecoder().decode(CommentPageResponse.self, from: Data(json.utf8))
        let reply = try #require(page.content.first)
        #expect(reply.parentCommentId == 12)
        #expect(reply.replyCount == 0)
        #expect(reply.attachment.references.count == 1)
        #expect(page.totalPages == 1)
    }

    @Test
    func relativeTimeBuckets() throws {
        let now = try #require(CommentTimeFormatter.date(from: "2026-10-05T12:00:00"))
        #expect(CommentTimeFormatter.relativeText(from: "2026-10-05T11:58:00.123456", now: now) == "방금")
        #expect(CommentTimeFormatter.relativeText(from: "2026-10-05T11:50:00", now: now) == "10분")
        #expect(CommentTimeFormatter.relativeText(from: "2026-10-05T10:00:00", now: now) == "2시간")
        #expect(CommentTimeFormatter.relativeText(from: "2026-10-03T12:00:00", now: now) == "2일")
    }
}
