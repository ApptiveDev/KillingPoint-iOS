import Foundation
import KakaoSDKTemplate
import Testing
@testable import KillingPart

struct MyCollectionDiaryShareTests {
    @Test
    func kakaoPayloadUsesUniversalLinkAndUploadedImageMetadata() throws {
        let diary = DiaryFeedModel.kakaoShareFixture()
        let shareURL = try #require(DeepLinkURLBuilder.diaryURL(diaryId: 1665))
        let kakaoExecutionParams = try #require(DeepLinkURLBuilder.kakaoDiaryExecutionParams(diaryId: 1665))
        let imageURL = try #require(URL(string: "https://k.kakaocdn.net/shared-image.png"))

        let payload = MyCollectionDiaryKakaoSharePayload.make(
            diary: diary,
            displayedContent: "오늘의 킬링파트",
            imageURL: imageURL,
            imageWidth: 1080,
            imageHeight: 1920,
            shareURL: shareURL,
            kakaoExecutionParams: kakaoExecutionParams
        )

        #expect(payload.title == "Song - Artist")
        #expect(payload.description == "오늘의 킬링파트")
        #expect(payload.imageURL == imageURL)
        #expect(payload.imageWidth == 1080)
        #expect(payload.imageHeight == 1920)
        #expect(payload.shareURL.absoluteString == "https://killingpart.com/diaries/1665")
        #expect(payload.kakaoExecutionParams["route"] == "diary")
        #expect(payload.kakaoExecutionParams["diaryId"] == "1665")

        let template = payload.makeFeedTemplate()
        let executionParams = try #require(template.content.link.iosExecutionParams)
        #expect(executionParams.contains("route=diary"))
        #expect(executionParams.contains("diaryId=1665"))
    }

    @Test
    func kakaoPayloadFallsBackWhenDiaryContentIsEmpty() throws {
        let diary = DiaryFeedModel.kakaoShareFixture()
        let shareURL = try #require(DeepLinkURLBuilder.diaryURL(diaryId: 1665))
        let kakaoExecutionParams = try #require(DeepLinkURLBuilder.kakaoDiaryExecutionParams(diaryId: 1665))
        let imageURL = try #require(URL(string: "https://k.kakaocdn.net/shared-image.png"))

        let payload = MyCollectionDiaryKakaoSharePayload.make(
            diary: diary,
            displayedContent: "   ",
            imageURL: imageURL,
            imageWidth: 1080,
            imageHeight: 1920,
            shareURL: shareURL,
            kakaoExecutionParams: kakaoExecutionParams
        )

        #expect(payload.description == "킬링파트에서 다이어리를 확인해 보세요.")
    }
}

private extension DiaryFeedModel {
    static func kakaoShareFixture() -> DiaryFeedModel {
        DiaryFeedModel(
            diaryId: 1665,
            artist: "Artist",
            musicTitle: "Song",
            albumImageUrl: "",
            content: "Content",
            videoUrl: "",
            scope: .public,
            duration: "00:10",
            totalDuration: "03:00",
            start: "00:01",
            end: "00:10",
            createDate: "2026-06-16T00:00:00",
            updateDate: "2026-06-16T00:00:00",
            isLiked: false,
            isStored: false,
            likeCount: 0,
            userId: 1,
            username: "Tester",
            tag: "@tester",
            profileImageUrl: nil,
            isMyPick: nil
        )
    }
}
