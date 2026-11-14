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
    func relativeTimeBuckets() throws {
        let now = try #require(CommentTimeFormatter.date(from: "2026-10-05T12:00:00"))
        #expect(CommentTimeFormatter.relativeText(from: "2026-10-05T11:58:00.123456", now: now) == "방금")
        #expect(CommentTimeFormatter.relativeText(from: "2026-10-05T11:50:00", now: now) == "10분")
        #expect(CommentTimeFormatter.relativeText(from: "2026-10-05T10:00:00", now: now) == "2시간")
        #expect(CommentTimeFormatter.relativeText(from: "2026-10-03T12:00:00", now: now) == "2일")
    }
}
