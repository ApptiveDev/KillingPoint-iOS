import SwiftUI

struct StoreKillingPartDetailRoute: Hashable {
    let diaryId: Int
    let initialDiary: StoredDiaryFeedModel

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.diaryId == rhs.diaryId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(diaryId)
    }
}

struct StoreKillingPartDetail: View {
    let diaryId: Int
    let diary: StoredDiaryFeedModel

    @Environment(\.scenePhase) private var scenePhase
    @State private var playerReloadToken = UUID()

    var body: some View {
        GeometryReader { proxy in
            let topContentInset = min(proxy.safeAreaInsets.top, AppSpacing.l) + AppSpacing.s
            let bottomContentInset = proxy.safeAreaInsets.bottom + AppSpacing.l

            ZStack {
                Image("my_background")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea(.container, edges: .all)

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.m) {
                        MyCollectionDiaryVideoSection(
                            videoURL: videoURL,
                            startSeconds: startSeconds,
                            endSeconds: endSeconds,
                            playerReloadToken: playerReloadToken
                        )

                        MyCollectionDiaryTrackSection(
                            artworkURL: diary.albumImageURL,
                            musicTitle: diary.musicTitle,
                            artist: diary.artist,
                            startMinuteSecondText: startMinuteSecondText,
                            endMinuteSecondText: endMinuteSecondText,
                            startProgress: startProgress,
                            endProgress: endProgress
                        )

                        actionButtonsSection
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, topContentInset)
                    .padding(.bottom, bottomContentInset)
                }
                .scrollIndicators(.hidden)
            }
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            playerReloadToken = UUID()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var actionButtonsSection: some View {
        VStack(spacing: AppSpacing.s) {
            Button(action: {}) {
                Text("내 킬링파트로 등록")
                    .font(AppFont.paperlogy6SemiBold(size: 14))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.primary600)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Button(action: {}) {
                Text("보관함에서 삭제")
                    .font(AppFont.paperlogy6SemiBold(size: 14))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.kpGray700)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private var startSeconds: Double {
        parsedSeconds(from: diary.start) ?? 0
    }

    private var endSeconds: Double {
        let parsedEnd = parsedSeconds(from: diary.end) ?? startSeconds
        return max(parsedEnd, startSeconds + 0.1)
    }

    private var totalSeconds: Double {
        let parsedTotal = parsedSeconds(from: diary.totalDuration) ?? 0
        return max(parsedTotal, endSeconds, 1)
    }

    private var startMinuteSecondText: String {
        TimeFormatter.minuteSecondText(from: startSeconds)
    }

    private var endMinuteSecondText: String {
        TimeFormatter.minuteSecondText(from: endSeconds)
    }

    private var startProgress: CGFloat {
        CGFloat(min(max(startSeconds / totalSeconds, 0), 1))
    }

    private var endProgress: CGFloat {
        CGFloat(min(max(endSeconds / totalSeconds, startSeconds / totalSeconds), 1))
    }

    private var videoURL: URL? {
        let trimmed = diary.videoUrl.trimmingCharacters(in: .whitespacesAndNewlines)
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

        if normalizedURLText.hasPrefix("//"),
           let parsed = URL(string: "https:\(normalizedURLText)") {
            return parsed
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
