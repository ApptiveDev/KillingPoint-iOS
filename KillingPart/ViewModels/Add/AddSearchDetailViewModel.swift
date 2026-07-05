import Foundation

enum AddSearchDetailStep: Equatable {
    case trim
    case comment
}

struct AddSearchDetailPrefill {
    let videoURL: String
    let start: String
    let end: String
    let totalDuration: String
    let selectedScope: DiaryScope?

    init(
        videoURL: String,
        start: String,
        end: String,
        totalDuration: String,
        selectedScope: DiaryScope? = nil
    ) {
        self.videoURL = videoURL
        self.start = start
        self.end = end
        self.totalDuration = totalDuration
        self.selectedScope = selectedScope
    }
}

struct AddSearchDetailPlaybackSeekRequest: Equatable {
    let seconds: Double
    let token: Int
}

@MainActor
final class AddSearchDetailViewModel: ObservableObject {
    @Published private(set) var videos: [YoutubeVideo] = []
    @Published private(set) var selectedVideo: YoutubeVideo?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var startSeconds: Double = 0
    @Published var endSeconds: Double = 0
    @Published private(set) var playbackSeconds: Double = 0
    @Published private(set) var playbackSeekRequest: AddSearchDetailPlaybackSeekRequest?
    @Published private(set) var boundaryLoopRange: ClosedRange<Double>?
    @Published private(set) var isHandleDragging = false
    @Published private(set) var currentStep: AddSearchDetailStep = .trim
    @Published var diaryContent: String = ""
    @Published var selectedScope: DiaryScope = .public
    @Published private(set) var isSavingDiary = false
    @Published var saveErrorMessage: String?

    let track: SpotifySimpleTrack

    private let youtubeService: YoutubeServicing
    private let diaryService: DiaryServicing
    private var hasLoaded = false
    private let minimumClipDuration: Double = 10
    private let maximumClipDurationLimit: Double = 30
    private let boundaryLoopDuration: Double = 2

    init(
        track: SpotifySimpleTrack,
        prefill: AddSearchDetailPrefill? = nil,
        youtubeService: YoutubeServicing = YoutubeService(),
        diaryService: DiaryServicing = DiaryService()
    ) {
        self.track = track
        self.youtubeService = youtubeService
        self.diaryService = diaryService

        if let prefill, applyPrefill(prefill) {
            hasLoaded = true
        }
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

    var effectivePlaybackStartSeconds: Double {
        boundaryLoopRange?.lowerBound ?? startSeconds
    }

    var effectivePlaybackEndSeconds: Double {
        boundaryLoopRange?.upperBound ?? endSeconds
    }

    func updatePlaybackSeconds(_ seconds: Double) {
        playbackSeconds = seconds
    }

    func activateBoundaryLoop(for control: AddSearchDetailTrimInteractionControl) {
        guard hasPlayableVideo else { return }

        switch control {
        case .left:
            let upperBound = min(startSeconds + boundaryLoopDuration, endSeconds)
            guard upperBound > startSeconds else { return }
            boundaryLoopRange = startSeconds...upperBound
        case .right:
            let lowerBound = max(endSeconds - boundaryLoopDuration, startSeconds)
            guard endSeconds > lowerBound else { return }
            boundaryLoopRange = lowerBound...endSeconds
        default:
            break
        }
    }

    func deactivateBoundaryLoop() {
        boundaryLoopRange = nil
    }

    func setHandleDragging(_ isDragging: Bool) {
        guard isHandleDragging != isDragging else { return }
        isHandleDragging = isDragging
    }

    func requestPlayback(from seconds: Double) {
        guard hasPlayableVideo else { return }
        let upperBound = max(endSeconds - 0.3, startSeconds)
        let clampedSeconds = min(max(seconds, startSeconds), upperBound)
        playbackSeekRequest = AddSearchDetailPlaybackSeekRequest(
            seconds: clampedSeconds,
            token: (playbackSeekRequest?.token ?? 0) + 1
        )
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

    private func applyPrefill(_ prefill: AddSearchDetailPrefill) -> Bool {
        let parsedStart = parsedSeconds(from: prefill.start) ?? 0
        let parsedEnd = parsedSeconds(from: prefill.end) ?? (parsedStart + minimumClipDuration)
        let parsedTotalDuration = parsedSeconds(from: prefill.totalDuration) ?? 0
        let resolvedDuration = max(parsedTotalDuration, parsedEnd, parsedStart + minimumClipDuration)

        guard
            let prefilledVideo = makePrefilledVideo(
                rawVideoURL: prefill.videoURL,
                duration: resolvedDuration
            )
        else {
            return false
        }

        videos = [prefilledVideo]
        selectedVideo = prefilledVideo
        updateRange(start: parsedStart, end: parsedEnd)
        if let selectedScope = prefill.selectedScope {
            self.selectedScope = selectedScope
        }
        currentStep = .comment
        errorMessage = nil
        saveErrorMessage = nil
        return true
    }

    private func makePrefilledVideo(rawVideoURL: String, duration: Double) -> YoutubeVideo? {
        guard let videoID = normalizedYouTubeVideoID(from: rawVideoURL) else {
            return nil
        }

        let embedURL = URL(string: "https://www.youtube.com/embed/\(videoID)?playsinline=1")
        return YoutubeVideo(
            id: videoID,
            title: track.title,
            duration: duration,
            url: embedURL
        )
    }

    private func parsedSeconds(from value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let raw = Double(trimmed) {
            return max(raw, 0)
        }

        let sanitized = trimmed.replacingOccurrences(of: "초", with: "")
        if sanitized.contains(":") {
            let parts = sanitized.split(separator: ":").map(String.init)
            guard
                parts.count == 2,
                let minutes = Double(parts[0]),
                let seconds = Double(parts[1])
            else {
                return nil
            }
            return max((minutes * 60) + seconds, 0)
        }

        if let raw = Double(sanitized) {
            return max(raw, 0)
        }

        return nil
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
        guard let selectedVideo else { return nil }

        if let normalizedVideoID = normalizedYouTubeVideoID(from: selectedVideo.id) {
            return normalizedVideoID
        }

        if
            let embedURLString = selectedVideo.embedURL?.absoluteString,
            let normalizedVideoID = normalizedYouTubeVideoID(from: embedURLString)
        {
            return normalizedVideoID
        }

        return nil
    }

    private func normalizedYouTubeVideoID(from value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return nil }

        if let extractedVideoID = extractYouTubeVideoID(from: trimmedValue) {
            return extractedVideoID
        }

        if
            !trimmedValue.contains("/"),
            !trimmedValue.contains("?"),
            !trimmedValue.contains("&"),
            !trimmedValue.contains("="),
            !trimmedValue.contains(".")
        {
            return trimmedValue
        }

        return nil
    }

    private func extractYouTubeVideoID(from value: String) -> String? {
        guard let components = URLComponents(string: value) else {
            return nil
        }

        let pathComponents = components.path.split(separator: "/").map(String.init)
        if let embedIndex = pathComponents.firstIndex(of: "embed"),
           pathComponents.indices.contains(embedIndex + 1) {
            let candidate = pathComponents[embedIndex + 1]
            if !candidate.isEmpty {
                return candidate
            }
        }

        if let shortsIndex = pathComponents.firstIndex(of: "shorts"),
           pathComponents.indices.contains(shortsIndex + 1) {
            let candidate = pathComponents[shortsIndex + 1]
            if !candidate.isEmpty {
                return candidate
            }
        }

        if let liveIndex = pathComponents.firstIndex(of: "live"),
           pathComponents.indices.contains(liveIndex + 1) {
            let candidate = pathComponents[liveIndex + 1]
            if !candidate.isEmpty {
                return candidate
            }
        }

        if
            let host = components.host?.lowercased(),
            host.contains("youtu.be"),
            let firstPath = pathComponents.first,
            !firstPath.isEmpty
        {
            return firstPath
        }

        if let watchVideoID = components.queryItems?.first(where: { $0.name == "v" })?.value,
           !watchVideoID.isEmpty {
            return watchVideoID
        }

        return nil
    }
}
