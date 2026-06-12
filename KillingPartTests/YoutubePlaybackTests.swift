import Foundation
import Testing
@testable import KillingPart

struct YoutubePlaybackTests {
    @Test
    func extractsRawYouTubeID() {
        let video = YoutubeVideo(id: "abc123XYZ_0", title: "Test", duration: 120)

        #expect(video.youtubeVideoID == "abc123XYZ_0")
        #expect(video.watchURL?.absoluteString == "https://www.youtube.com/watch?v=abc123XYZ_0")
        #expect(video.canonicalEmbedURL?.absoluteString == "https://www.youtube.com/embed/abc123XYZ_0?playsinline=1&enablejsapi=1")
    }

    @Test
    func extractsWatchURLYouTubeIDFromDecodedPayload() throws {
        let data = Data(
            """
            {
              "id": "",
              "title": "Watch URL",
              "duration": "PT1M30S",
              "url": "https://www.youtube.com/watch?v=watch123"
            }
            """.utf8
        )

        let video = try JSONDecoder().decode(YoutubeVideo.self, from: data)

        #expect(video.youtubeVideoID == "watch123")
        #expect(video.duration == 90)
        #expect(video.embedURL?.absoluteString == "https://www.youtube.com/embed/watch123?playsinline=1&enablejsapi=1")
    }

    @Test
    func extractsShortURLYouTubeID() {
        let video = YoutubeVideo(
            id: "https://youtu.be/short123",
            title: "Short",
            duration: 60
        )

        #expect(video.youtubeVideoID == "short123")
        #expect(video.thumbnailURL?.absoluteString == "https://i.ytimg.com/vi/short123/hqdefault.jpg")
    }

    @Test
    func returnsNilForUnsupportedYouTubeURL() {
        let video = YoutubeVideo(
            id: "https://example.com/not-youtube",
            title: "Invalid",
            duration: 60
        )

        #expect(video.youtubeVideoID == nil)
        #expect(video.canonicalEmbedURL == nil)
        #expect(video.watchURL == nil)
    }

    @Test
    func normalizesPlaybackRange() {
        let range = YoutubePlaybackRange(startSeconds: -3.4567, endSeconds: -1)

        #expect(range.startSeconds == 0)
        #expect(range.endSeconds == 0.1)
        #expect(range.contains(0.01))
        #expect(!range.contains(0.2))
    }

    @Test
    func mutedFallbackRequiresEligibleAutoplayFailure() {
        let policy = YoutubePlayerAutoplayPolicy.default

        #expect(
            policy.shouldUseMutedFallback(
                allowsMutedAutoplayFallback: true,
                hasUsedMutedFallback: false,
                hasUserInteracted: false,
                elapsedSinceUnmutedAttempt: 1.3
            )
        )
        #expect(
            !policy.shouldUseMutedFallback(
                allowsMutedAutoplayFallback: true,
                hasUsedMutedFallback: false,
                hasUserInteracted: true,
                elapsedSinceUnmutedAttempt: 1.3
            )
        )
        #expect(
            !policy.shouldUseMutedFallback(
                allowsMutedAutoplayFallback: true,
                hasUsedMutedFallback: true,
                hasUserInteracted: false,
                elapsedSinceUnmutedAttempt: 1.3
            )
        )
    }

    @Test
    func mutedFallbackStartsImmediatelyInLowPowerMode() {
        let policy = YoutubePlayerAutoplayPolicy.default

        #expect(
            policy.shouldUseMutedFallback(
                allowsMutedAutoplayFallback: true,
                hasUsedMutedFallback: false,
                hasUserInteracted: false,
                isLowPowerModeEnabled: true,
                elapsedSinceUnmutedAttempt: 0
            )
        )
    }
}
