import SwiftUI

enum DiaryCommentFormat {
    /// 99 초과면 "99+"
    static func count(_ value: Int) -> String {
        value > 99 ? "99+" : "\(value)"
    }

    /// 13자 + "..."
    static func previewText(_ text: String) -> String {
        text.count > 13 ? String(text.prefix(13)) + "..." : text
    }

    static func url(_ raw: String?) -> URL? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        if let url = URL(string: raw), url.scheme != nil { return url }
        return URL(string: "https://\(raw)")
    }
}

enum DiaryCommentColors {
    static let greenSurface = Color(hex: "#1F2E14")
    static let greenDivider = Color(hex: "#4A6B1F")
    static let inputBackground = Color(hex: "#3A3B38")
    static let avatarPlaceholder = Color(hex: "#9A9A9A")
}

// MARK: - 상단 댓글 버튼 (상대방 컬렉션 상세: [♥][💬N][🔖])

struct DiaryCommentCapsuleButton: View {
    let commentCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                // 옆 좋아요 하트(SF Symbol)와 크기를 똑같이 맞추려고 투명 하트를 틀로 사용
                Image(systemName: "heart")
                    .opacity(0)
                    .overlay {
                        // PNG 자체 여백 때문에 하트보다 작아 보여 확대 (실기기 비교 기준)
                        Image("ic_comment")
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(1.45)
                    }

                if commentCount > 0 {
                    Text(DiaryCommentFormat.count(commentCount))
                        .font(AppFont.paperlogy4Regular(size: 12))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("댓글 \(commentCount)개")
    }
}

// MARK: - 피드 카드 댓글 바 (아바타 3개 + 2초 로테이션 + 댓글 수)

struct DiaryCommentPreviewBar: View {
    let preview: DiaryCommentPreview
    let onTap: () -> Void
    /// 카드가 보일 때마다 가장 최신 댓글부터 로테이션 시작
    @State private var rotationStartDate = Date()

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.s) {
                avatarStack

                rotatingText
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(DiaryCommentFormat.count(preview.commentCount))
                    .font(AppFont.paperlogy5Medium(size: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, AppSpacing.s)
            .frame(height: 44)
            .background(DiaryCommentColors.greenSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("댓글 \(preview.commentCount)개 보기")
        .onAppear { rotationStartDate = Date() }
    }

    /// 같은 유저 중복 제거 후 최대 3명
    private var avatarURLs: [URL?] {
        var seen = Set<Int>()
        return preview.comments
            .filter { seen.insert($0.userId).inserted }
            .prefix(3)
            .map { DiaryCommentFormat.url($0.profileImageUrl) }
    }

    private var avatarStack: some View {
        HStack(spacing: -10) {
            ForEach(Array(avatarURLs.enumerated()), id: \.offset) { _, url in
                DiaryCommentAvatar(url: url, size: 26)
                    .overlay(Circle().stroke(DiaryCommentColors.greenSurface, lineWidth: 1.5))
            }
        }
    }

    @ViewBuilder
    private var rotatingText: some View {
        if preview.comments.isEmpty {
            previewLabel("첫 댓글을 남겨보세요!")
        } else if preview.comments.count == 1 {
            previewLabel(DiaryCommentFormat.previewText(preview.comments[0].content))
        } else {
            TimelineView(.periodic(from: rotationStartDate, by: 2)) { context in
                let elapsed = max(context.date.timeIntervalSince(rotationStartDate), 0)
                let index = Int(elapsed / 2) % preview.comments.count
                previewLabel(DiaryCommentFormat.previewText(preview.comments[index].content))
                    .id(index)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                    .animation(.easeInOut(duration: 0.35), value: index)
            }
            .clipped()
        }
    }

    private func previewLabel(_ text: String) -> some View {
        Text(text)
            .font(AppFont.paperlogy4Regular(size: 13))
            .foregroundStyle(.white)
            .lineLimit(1)
    }
}

struct DiaryCommentAvatar: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            if case .success(let image) = phase {
                image.resizable().scaledToFill()
            } else {
                DiaryCommentColors.avatarPlaceholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
