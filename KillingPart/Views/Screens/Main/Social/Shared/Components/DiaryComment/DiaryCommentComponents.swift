import SwiftUI

// MARK: - UI 모델 (API 연동 시 commentPreview / CommentResponse 에서 매핑)

struct DiaryCommentPreviewItem: Identifiable {
    let commentId: Int
    let userId: Int
    let profileImageUrl: String?
    let content: String

    var id: Int { commentId }
}

struct DiaryCommentPreview {
    let commentCount: Int
    let comments: [DiaryCommentPreviewItem]

    static let empty = DiaryCommentPreview(commentCount: 0, comments: [])
}

struct DiaryCommentItem: Identifiable {
    let commentId: Int
    let username: String
    let profileImageUrl: String?
    let text: String
    let relativeTime: String
    let isLiked: Bool
    let likeCount: Int
    let replies: [DiaryCommentItem]

    var id: Int { commentId }
}

// ponytail: 목업 데이터. 페이지별 API 명세 받으면 commentPreview / 댓글 목록 API 로 교체
enum DiaryCommentMock {
    static let preview = DiaryCommentPreview(
        commentCount: 8,
        comments: [
            .init(commentId: 31, userId: 7, profileImageUrl: nil, content: "안녕하세요! 좋은 킬파 잘 감상했습니다. 너무"),
            .init(commentId: 29, userId: 3, profileImageUrl: nil, content: "@이진원 레전드입니다."),
            .init(commentId: 25, userId: 5, profileImageUrl: nil, content: "안녕하세요! 히히")
        ]
    )

    static let comments: [DiaryCommentItem] = [
        item(1, "안녕하세요! 좋은 킬파 잘 감상했습니다.", liked: false, likes: 24),
        item(2, "@goodmusic 레전드입니다."),
        item(3, "안녕하세요! 좋은 킬파 잘 감상했습니다. 너무 좋네요. 다음에도 좋은 곡 꼭 올려주세요 ㅎㅎ."),
        item(4, "안녕하세요! 히히", replies: (0..<7).map { item(100 + $0, "답글입니다 \($0 + 1)") }),
        item(5, "안녕하세요! 히히", replies: [item(200, "안녕하세요! 히히")]),
        item(6, "안녕하세요! 좋은 킬파 잘 감상했습니다. 너무 좋네요. 다음에도 좋은 곡 꼭 올려주세요 ㅎㅎ.")
    ]

    private static func item(
        _ id: Int,
        _ text: String,
        liked: Bool = true,
        likes: Int = 25,
        replies: [DiaryCommentItem] = []
    ) -> DiaryCommentItem {
        DiaryCommentItem(
            commentId: id,
            username: "김기영",
            profileImageUrl: nil,
            text: text,
            relativeTime: "2시간",
            isLiked: liked,
            likeCount: likes,
            replies: replies
        )
    }
}

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

private enum DiaryCommentColors {
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
                Image("ic_comment")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)

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
            TimelineView(.periodic(from: .now, by: 2)) { context in
                let index = Int(context.date.timeIntervalSinceReferenceDate / 2) % preview.comments.count
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

// MARK: - 댓글 바텀시트

struct DiaryCommentSheet: View {
    let commentCount: Int
    let comments: [DiaryCommentItem]

    @State private var draft = ""
    @State private var expandedCommentIds: Set<Int> = []
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(comments) { comment in
                        commentThread(comment)
                    }
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.vertical, AppSpacing.l)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) { inputBar }
        .background(Color.black)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color.black)
        .presentationCornerRadius(24)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(AppColors.primary100)
                .frame(width: 56, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            HStack(spacing: 6) {
                Text("댓글")
                    .font(AppFont.paperlogy5Medium(size: 18))
                Text(DiaryCommentFormat.count(commentCount))
                    .font(AppFont.paperlogy7Bold(size: 18))
            }
            .foregroundStyle(AppColors.primary600)
            .padding(.horizontal, AppSpacing.l)
            .padding(.top, AppSpacing.m)
            .padding(.bottom, AppSpacing.s)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DiaryCommentColors.greenSurface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DiaryCommentColors.greenDivider)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func commentThread(_ comment: DiaryCommentItem) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            DiaryCommentRow(comment: comment, avatarSize: 40)

            if !comment.replies.isEmpty {
                let isExpanded = expandedCommentIds.contains(comment.commentId)

                Button {
                    if isExpanded {
                        expandedCommentIds.remove(comment.commentId)
                    } else {
                        expandedCommentIds.insert(comment.commentId)
                    }
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Rectangle()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 28, height: 1)
                        Text(isExpanded ? "답글 숨기기" : "답글 \(comment.replies.count)개 보기")
                            .font(AppFont.paperlogy4Regular(size: 11))
                            .foregroundStyle(Color.kpGray300)
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading, 40 + AppSpacing.s)
                .padding(.top, -6)

                if isExpanded {
                    VStack(alignment: .leading, spacing: AppSpacing.m) {
                        ForEach(comment.replies) { reply in
                            DiaryCommentRow(comment: reply, avatarSize: 40)
                        }
                    }
                    .padding(.leading, 40 + AppSpacing.s)
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: AppSpacing.xs) {
            TextField(
                "",
                text: $draft,
                prompt: Text("댓글을 달아보세요!").foregroundColor(.white.opacity(0.45)),
                axis: .vertical
            )
            .lineLimit(1...4)
            .font(AppFont.paperlogy4Regular(size: 15))
            .foregroundStyle(.white)
            .focused($isInputFocused)
            .padding(.horizontal, AppSpacing.m)
            .padding(.vertical, 10)
            .background(DiaryCommentColors.inputBackground, in: RoundedRectangle(cornerRadius: 6))

            Button {
                // TODO: 댓글 작성 API 연동
                draft = ""
                isInputFocused = false
            } label: {
                Text("등록")
                    .font(AppFont.paperlogy6SemiBold(size: 14))
                    .foregroundStyle(.black)
                    .padding(.horizontal, AppSpacing.xs)
                    .frame(height: 38)
                    .background(AppColors.primary600, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.xs)
        .background(Color.black)
    }
}

private struct DiaryCommentRow: View {
    let comment: DiaryCommentItem
    let avatarSize: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.s) {
            DiaryCommentAvatar(url: DiaryCommentFormat.url(comment.profileImageUrl), size: avatarSize)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: AppSpacing.xs) {
                    Text(comment.username)
                        .font(AppFont.paperlogy7Bold(size: 14))
                        .foregroundStyle(.white)
                    Text(comment.relativeTime)
                        .font(AppFont.paperlogy4Regular(size: 11))
                        .foregroundStyle(Color.kpGray300)
                }

                mentionHighlightedText(comment.text)
                    .font(AppFont.paperlogy4Regular(size: 14))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: AppSpacing.s) {
                    HStack(spacing: 2) {
                        Image(systemName: comment.isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 10))
                            .foregroundStyle(comment.isLiked ? Color.kpPrimary : .white)
                        Text(comment.likeCount.formatted())
                    }
                    Text("답글달기")
                    Image(systemName: "ellipsis")
                }
                .font(AppFont.paperlogy4Regular(size: 11))
                .foregroundStyle(Color.kpGray300)
                .padding(.top, 2)
            }
        }
    }

    // ponytail: "@단어" 를 단순 하이라이트. API 연동 시 references(atOrders/len, UTF-16) 기반으로 교체
    private func mentionHighlightedText(_ text: String) -> Text {
        text.split(separator: " ", omittingEmptySubsequences: false)
            .enumerated()
            .reduce(Text("")) { result, pair in
                let word = String(pair.element)
                let piece = Text((pair.offset == 0 ? "" : " ") + word)
                return result + (word.hasPrefix("@") ? piece.foregroundColor(AppColors.primary600) : piece)
            }
    }
}

private struct DiaryCommentAvatar: View {
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
