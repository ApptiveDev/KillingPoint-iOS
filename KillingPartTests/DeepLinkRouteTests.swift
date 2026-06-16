import Foundation
import Testing
@testable import KillingPart

struct DeepLinkRouteTests {
    @Test
    func parsesDiaryUniversalLink() throws {
        let url = try #require(URL(string: "https://killingpart.com/diaries/123"))

        #expect(DeepLinkRoute(url: url) == .socialDiary(diaryId: 123))
    }

    @Test
    func parsesCustomSchemeDiaryLink() throws {
        let url = try #require(URL(string: "killingpart://diaries/1665"))

        #expect(DeepLinkRoute(url: url) == .socialDiary(diaryId: 1665))
    }

    @Test
    func rejectsNonKillingPartHost() throws {
        let url = try #require(URL(string: "https://example.com/diaries/123"))

        #expect(DeepLinkRoute(url: url) == nil)
    }

    @Test
    func rejectsEmptyDiaryID() throws {
        let url = try #require(URL(string: "https://killingpart.com/diaries/"))

        #expect(DeepLinkRoute(url: url) == nil)
    }

    @Test
    func rejectsNegativeDiaryID() throws {
        let url = try #require(URL(string: "https://killingpart.com/diaries/-1"))

        #expect(DeepLinkRoute(url: url) == nil)
    }

    @Test
    func rejectsNonNumericDiaryID() throws {
        let url = try #require(URL(string: "https://killingpart.com/diaries/abc"))

        #expect(DeepLinkRoute(url: url) == nil)
    }

    @Test
    func buildsDiaryUniversalLink() {
        #expect(
            DeepLinkURLBuilder.diaryURL(diaryId: 123)?.absoluteString == "https://killingpart.com/diaries/123"
        )
        #expect(
            DeepLinkURLBuilder.customDiaryURL(diaryId: 123)?.absoluteString == "killingpart://diaries/123"
        )
        #expect(DeepLinkURLBuilder.diaryURL(diaryId: 0) == nil)
        #expect(DeepLinkURLBuilder.customDiaryURL(diaryId: 0) == nil)
    }
}
