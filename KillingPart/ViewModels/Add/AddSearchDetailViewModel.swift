import Foundation

@MainActor
final class AddSearchDetailViewModel: ObservableObject {
    @Published private(set) var videos: [YoutubeVideo] = []
    @Published private(set) var selectedVideo: YoutubeVideo?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var startSeconds: Double = 0
    @Published var endSeconds: Double = 0

    let track: SpotifySimpleTrack

    private let youtubeService: YoutubeServicing
    private var hasLoaded = false
    private let minimumClipDuration: Double = 1
    private let maximumClipDurationLimit: Double = 30

    init(
        track: SpotifySimpleTrack,
        youtubeService: YoutubeServicing = YoutubeService()
    ) {
        self.track = track
        self.youtubeService = youtubeService
    }

    var maxDuration: Double {
        max(selectedVideo?.duration ?? 0, 0)
    }

    var hasPlayableVideo: Bool {
        selectedVideo != nil
    }

    var clipDuration: Double {
        max(endSeconds - startSeconds, 0)
    }

    var startTimeText: String {
        formatTime(seconds: startSeconds)
    }

    var endTimeText: String {
        formatTime(seconds: endSeconds)
    }

    var clipDurationText: String {
        formatTime(seconds: clipDuration)
    }

    var selectedVideoDurationText: String {
        formatTime(seconds: maxDuration)
    }

    var maximumStartSeconds: Double {
        let minGap = maxDuration >= minimumClipDuration ? minimumClipDuration : 0
        return max(endSeconds - minGap, 0)
    }

    var minimumEndSeconds: Double {
        let minGap = maxDuration >= minimumClipDuration ? minimumClipDuration : 0
        return min(maxDuration, startSeconds + minGap)
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await loadVideos()
    }

    func retry() async {
        await loadVideos()
    }

    func selectVideo(_ video: YoutubeVideo) {
        guard selectedVideo?.id != video.id else { return }
        selectedVideo = video
        resetClipRange()
    }

    func updateStart(_ value: Double) {
        guard maxDuration > 0 else {
            startSeconds = 0
            return
        }

        let minGap = maxDuration >= minimumClipDuration ? minimumClipDuration : 0
        let maxGap = min(maxDuration, maximumClipDurationLimit)
        let lowerBound = max(endSeconds - maxGap, 0)
        let upperBound = max(endSeconds - minGap, 0)
        startSeconds = min(max(value, lowerBound), upperBound)
    }

    func updateEnd(_ value: Double) {
        guard maxDuration > 0 else {
            endSeconds = 0
            return
        }

        let minGap = maxDuration >= minimumClipDuration ? minimumClipDuration : 0
        let maxGap = min(maxDuration, maximumClipDurationLimit)
        let lowerBound = min(maxDuration, startSeconds + minGap)
        let upperBound = min(maxDuration, startSeconds + maxGap)
        endSeconds = max(min(value, upperBound), lowerBound)
    }

    func updateRange(start: Double, end: Double) {
        guard maxDuration > 0 else {
            startSeconds = 0
            endSeconds = 0
            return
        }

        let minGap = maxDuration >= minimumClipDuration ? minimumClipDuration : 0
        let maxGap = min(maxDuration, maximumClipDurationLimit)

        var clampedStart = min(max(start, 0), maxDuration)
        var clampedEnd = min(max(end, 0), maxDuration)
        if clampedEnd < clampedStart {
            swap(&clampedStart, &clampedEnd)
        }

        var gap = clampedEnd - clampedStart
        gap = min(max(gap, minGap), maxGap)

        if clampedStart + gap > maxDuration {
            clampedStart = max(maxDuration - gap, 0)
        }
        clampedEnd = clampedStart + gap

        startSeconds = clampedStart
        endSeconds = clampedEnd
    }

    private func loadVideos() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetchedVideos = try await youtubeService.searchVideos(
                title: track.title,
                artist: track.artist
            )
            videos = fetchedVideos
            selectedVideo = fetchedVideos.first
            resetClipRange()
        } catch {
            videos = []
            selectedVideo = nil
            startSeconds = 0
            endSeconds = 0
            errorMessage = resolveErrorMessage(from: error)
        }
    }

    private func resetClipRange() {
        startSeconds = 0
        endSeconds = min(maxDuration, maximumClipDurationLimit)
    }

    private func resolveErrorMessage(from error: Error) -> String {
        if let youtubeError = error as? YoutubeServiceError {
            return youtubeError.errorDescription ?? "유튜브 검색에 실패했어요."
        }

        if let localizedError = error as? LocalizedError {
            return localizedError.errorDescription ?? "유튜브 검색에 실패했어요."
        }

        return "유튜브 검색에 실패했어요."
    }

    private func formatTime(seconds: Double) -> String {
        let safeSeconds = max(Int(seconds.rounded(.down)), 0)
        let hours = safeSeconds / 3600
        let minutes = (safeSeconds % 3600) / 60
        let remainingSeconds = safeSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }

        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}
