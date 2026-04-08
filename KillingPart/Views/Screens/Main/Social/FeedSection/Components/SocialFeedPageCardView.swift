import SwiftUI

struct SocialFeedPageCardView: View {
    let feed: DiaryFeedModel
    let isVideoPlaying: Bool
    let playbackFocusToken: Int
    let elapsedInCurrentRange: TimeInterval
    let shouldLoadPlayer: Bool
    let onProfileTap: () -> Void
    let onLikeTap: () -> Void
    let onLikeLongPress: () -> Void
    let onStoreTap: () -> Void
    let onReportTap: () -> Void
    let onVideoPlaybackEnded: () -> Void
    @State private var shouldIgnoreNextLikeTap = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    HStack {
                        Button(action: onProfileTap) {
                            SocialFeedProfileView(feed: feed)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Menu {
                            Button {
                                onReportTap()
                            } label: {
                                Label {
                                    Text("신고하기")
                                } icon: {
                                    Image(systemName: "light.beacon.max")
                                }
                                .tint(.red)
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.1), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(alignment: .top, spacing: AppSpacing.s) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(feed.musicTitle)
                                .font(AppFont.paperlogy6SemiBold(size: 16))
                                .foregroundStyle(.white)
                                .lineLimit(2)

                            Text(feed.artist)
                                .font(AppFont.paperlogy4Regular(size: 14))
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(2)
                        }

                        Spacer(minLength: 0)

                        HStack(spacing: AppSpacing.s) {
                            HStack(spacing: 4) {
                                Button {
                                    if shouldIgnoreNextLikeTap {
                                        shouldIgnoreNextLikeTap = false
                                        return
                                    }
                                    onLikeTap()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: feed.isLiked ? "heart.fill" : "heart")
                                            .foregroundStyle(feed.isLiked ? Color.kpPrimary : .white.opacity(0.75))
                                        Text(feed.likeCount.formatted())
                                            .font(AppFont.paperlogy4Regular(size: 12))
                                            .foregroundStyle(.white.opacity(0.85))
                                    }
                                    .padding(.horizontal, AppSpacing.xs)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.1), in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .simultaneousGesture(
                                    LongPressGesture(minimumDuration: 0.45)
                                        .onEnded { _ in
                                            shouldIgnoreNextLikeTap = true
                                            onLikeLongPress()
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                shouldIgnoreNextLikeTap = false
                                            }
                                        }
                                )
                            }

                            Button {
                                onStoreTap()
                            } label: {
                                Image(systemName: feed.isStored ? "bookmark.fill" : "bookmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppColors.primary600)
                                    .padding(.horizontal, AppSpacing.xs)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.1), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    SocialFeedVideoSection(
                        feed: feed,
                        isVideoPlaying: isVideoPlaying,
                        playbackFocusToken: playbackFocusToken,
                        shouldLoadPlayer: shouldLoadPlayer,
                        onPlaybackEnded: onVideoPlaybackEnded
                    )

                    VStack(alignment: .center, spacing: AppSpacing.xl) {
                        Text("킬링파트 일기")
                            .font(AppFont.paperlogy5Medium(size: 13))
                            .foregroundStyle(Color.kpGray300)
                            .frame(maxWidth: .infinity, alignment: .center)

                        Text(feed.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "작성된 킬링파트 일기가 없어요." : feed.content)
                            .font(AppFont.paperlogy4Regular(size: 13))
                            .foregroundStyle(.white)
                            .lineSpacing(2)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(AppSpacing.m)
            }
            .scrollIndicators(.hidden)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("재생 구간")
                    .font(AppFont.paperlogy5Medium(size: 13))
                    .foregroundStyle(AppColors.primary600)

                SocialFeedPlaybackRangeBar(
                    startSeconds: parsedSeconds(from: feed.start) ?? 0,
                    endSeconds: parsedEndSeconds,
                    totalSeconds: parsedTotalSeconds,
                    elapsedInCurrentRange: elapsedInCurrentRange
                )
                .frame(height: 34)
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.l)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var parsedEndSeconds: Double {
        let start = parsedSeconds(from: feed.start) ?? 0
        return max(parsedSeconds(from: feed.end) ?? start, start + 0.1)
    }

    private var parsedTotalSeconds: Double {
        max(parsedSeconds(from: feed.totalDuration) ?? 0, parsedEndSeconds, 1)
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
}

private struct SocialFeedVideoSection: View {
    let feed: DiaryFeedModel
    let isVideoPlaying: Bool
    let playbackFocusToken: Int
    let shouldLoadPlayer: Bool
    let onPlaybackEnded: () -> Void

    var body: some View {
        Group {
            if shouldLoadPlayer {
                YoutubePlayerView(
                    videoURL: resolvedVideoURL(from: feed.videoUrl),
                    startSeconds: parsedSeconds(from: feed.start) ?? 0,
                    endSeconds: parsedEndSeconds,
                    isPlaying: isVideoPlaying,
                    playbackFocusToken: playbackFocusToken,
                    shouldLoopPlayback: false,
                    onPlaybackEnded: onPlaybackEnded
                )
                .id(feed.diaryId)
            } else {
                Color.black.opacity(0.3)
                    .id("placeholder-\(feed.diaryId)")
            }
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
    }

    private var parsedEndSeconds: Double {
        let minimumRangeDuration = 1.0
        let start = parsedSeconds(from: feed.start) ?? 0
        let total = parsedSeconds(from: feed.totalDuration) ?? 0
        if let explicitEnd = parsedSeconds(from: feed.end), explicitEnd > start + minimumRangeDuration {
            return explicitEnd
        }
        if total > start + minimumRangeDuration {
            return total
        }
        return start + 15
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
            if parts.count == 2,
               let minutes = Double(parts[0]),
               let seconds = Double(parts[1]) {
                return max((minutes * 60) + seconds, 0)
            }
            if parts.count == 3,
               let hours = Double(parts[0]),
               let minutes = Double(parts[1]),
               let seconds = Double(parts[2]) {
                return max((hours * 3600) + (minutes * 60) + seconds, 0)
            }
            return nil
        }

        if let raw = Double(sanitized) {
            return max(raw, 0)
        }

        return nil
    }

    private func resolvedVideoURL(from rawVideoURL: String) -> URL? {
        let trimmed = rawVideoURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalizedURLText: String
        if isLikelyYouTubeVideoID(trimmed) {
            normalizedURLText = "https://www.youtube.com/embed/\(trimmed)?playsinline=1"
        } else {
            normalizedURLText = trimmed
        }

        if let parsed = URL(string: normalizedURLText), parsed.scheme != nil {
            return parsed
        }

        if normalizedURLText.hasPrefix("//") {
            return URL(string: "https:\(normalizedURLText)")
        }

        return URL(string: "https://\(normalizedURLText)")
    }

    private func isLikelyYouTubeVideoID(_ value: String) -> Bool {
        if value.hasPrefix("//") {
            return false
        }

        if let components = URLComponents(string: value),
           components.scheme != nil || components.host != nil {
            return false
        }

        return !value.contains("/")
            && !value.contains("?")
            && !value.contains("&")
            && !value.contains("=")
            && !value.contains(".")
    }
}
