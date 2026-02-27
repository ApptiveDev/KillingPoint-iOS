import Foundation

enum AddSearchDetailStep: Equatable {
    case trim
    case comment
}

@MainActor
final class AddSearchDetailViewModel: ObservableObject {
    @Published private(set) var videos: [YoutubeVideo] = []
    @Published private(set) var selectedVideo: YoutubeVideo?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var startSeconds: Double = 0
    @Published var endSeconds: Double = 0
    @Published private(set) var currentStep: AddSearchDetailStep = .trim
    @Published var diaryContent: String = ""
    @Published var selectedScope: DiaryScope = .public
    @Published private(set) var isSavingDiary = false
    @Published var saveErrorMessage: String?

    let track: SpotifySimpleTrack

    private let youtubeService: YoutubeServicing
    private let diaryService: DiaryServicing
    private var hasLoaded = false
    private let minimumClipDuration: Double = 1
    private let maximumClipDurationLimit: Double = 30

    init(
        track: SpotifySimpleTrack,
        youtubeService: YoutubeServicing = YoutubeService(),
        diaryService: DiaryServicing = DiaryService()
    ) {
        self.track = track
        self.youtubeService = youtubeService
        self.diaryService = diaryService
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
        TimeFormatter.secondsString(from: startSeconds)
    }

    var endTimeText: String {
        TimeFormatter.secondsString(from: endSeconds)
    }

    var clipDurationText: String {
        TimeFormatter.secondsString(from: clipDuration)
    }

    var selectedVideoDurationText: String {
        TimeFormatter.secondsString(from: maxDuration)
    }

    var maximumStartSeconds: Double {
        let minGap = maxDuration >= minimumClipDuration ? minimumClipDuration : 0
        return max(endSeconds - minGap, 0)
    }

    var minimumEndSeconds: Double {
        let minGap = maxDuration >= minimumClipDuration ? minimumClipDuration : 0
        return min(maxDuration, startSeconds + minGap)
    }

    var canMoveToCommentStep: Bool {
        hasPlayableVideo && videoURLForSave != nil && clipDuration > 0
    }

    var canSaveDiary: Bool {
        canMoveToCommentStep && !trimmedDiaryContent.isEmpty && !isSavingDiary
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

    @discardableResult
    func moveToCommentStep() -> Bool {
        guard canMoveToCommentStep else {
            saveErrorMessage = "영상과 구간을 먼저 선택해 주세요."
            return false
        }

        saveErrorMessage = nil
        currentStep = .comment
        return true
    }

    func moveToTrimStep() {
        saveErrorMessage = nil
        currentStep = .trim
    }

    func submitDiary() async -> Bool {
        guard !isSavingDiary else { return false }
        guard let request = buildDiaryCreateRequest() else {
            return false
        }

        isSavingDiary = true
        saveErrorMessage = nil
        defer { isSavingDiary = false }

        do {
            _ = try await diaryService.createDiary(request: request)
            NotificationCenter.default.post(name: .diaryCreated, object: nil)
            return true
        } catch {
            if Task.isCancelled { return false }
            saveErrorMessage = resolveSaveErrorMessage(from: error)
            return false
        }
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

    private func resolveSaveErrorMessage(from error: Error) -> String {
        if let diaryError = error as? DiaryServiceError {
            return diaryError.errorDescription ?? "일기 저장에 실패했어요."
        }

        if let localizedError = error as? LocalizedError {
            return localizedError.errorDescription ?? "일기 저장에 실패했어요."
        }

        return "일기 저장에 실패했어요."
    }

    private func buildDiaryCreateRequest() -> DiaryCreateRequest? {
        let trimmedArtist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMusicTitle = track.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trackAlbumImageUrl = (track.albumImageUrl ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = trimmedDiaryContent
        guard !trimmedArtist.isEmpty, !trimmedMusicTitle.isEmpty else {
            saveErrorMessage = "곡 정보가 올바르지 않아 저장할 수 없어요."
            return nil
        }
        let resolvedAlbumImageUrl = !trackAlbumImageUrl.isEmpty
            ? trackAlbumImageUrl
            : selectedVideo?.thumbnailURL?.absoluteString
        guard let albumImageUrl = resolvedAlbumImageUrl, !albumImageUrl.isEmpty else {
            saveErrorMessage = "앨범 이미지가 없어 저장할 수 없어요."
            return nil
        }
        guard let videoUrl = videoURLForSave else {
            saveErrorMessage = "영상 정보를 확인할 수 없어 저장할 수 없어요."
            return nil
        }
        guard !trimmedContent.isEmpty else {
            saveErrorMessage = "코멘트를 입력해 주세요."
            return nil
        }

        return DiaryCreateRequest(
            artist: trimmedArtist,
            musicTitle: trimmedMusicTitle,
            albumImageUrl: albumImageUrl,
            videoUrl: videoUrl,
            scope: selectedScope,
            content: trimmedContent,
            duration: clipDurationText,
            totalDuration: selectedVideoDurationText,
            start: startTimeText,
            end: endTimeText
        )
    }

    private var trimmedDiaryContent: String {
        diaryContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var videoURLForSave: String? {
        if let embedURL = selectedVideo?.embedURL?.absoluteString {
            return embedURL
        }

        guard let selectedVideo else { return nil }
        let videoID = selectedVideo.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !videoID.isEmpty else { return nil }
        return "https://www.youtube.com/watch?v=\(videoID)"
    }
}
