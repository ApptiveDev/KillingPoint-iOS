import Foundation

@MainActor
final class DiaryCommentViewModel: ObservableObject {
    enum InputMode: Equatable {
        case normal
        /// parentCommentId 는 항상 원댓글 id (답글의 답글 없음)
        case reply(parentCommentId: Int, targetName: String)
        case edit(comment: CommentResponse)
    }

    static let maxTextLength = 500
    private static let pageSize = 20
    // ponytail: 답글은 한 번에 최대 100개. 그 이상 달리는 경우가 생기면 페이지 더보기 추가
    private static let replyPageSize = 100

    let diaryId: Int

    @Published private(set) var commentCount: Int
    @Published private(set) var comments: [CommentResponse] = []
    @Published private(set) var replies: [Int: [CommentResponse]] = [:]
    @Published private(set) var expandedCommentIds: Set<Int> = []
    @Published private(set) var loadingReplyIds: Set<Int> = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var inputMode: InputMode = .normal
    @Published var draft = "" {
        didSet {
            if draft.count > Self.maxTextLength {
                draft = String(draft.prefix(Self.maxTextLength))
            }
        }
    }
    @Published var errorMessage: String?
    /// 등록 후 스크롤할 댓글 id
    @Published private(set) var scrollTargetId: Int?

    private var currentPage = 0
    private var hasMorePages = true
    private var mentionCandidates: [CommentMentionCandidate] = []

    private let commentService: CommentServicing
    private let userService: UserServicing

    init(
        diaryId: Int,
        initialCommentCount: Int,
        commentService: CommentServicing = CommentService(),
        userService: UserServicing = UserService()
    ) {
        self.diaryId = diaryId
        self.commentCount = initialCommentCount
        self.commentService = commentService
        self.userService = userService
    }

    var canSubmit: Bool {
        !isSubmitting && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - 목록

    func loadInitial() async {
        currentPage = 0
        hasMorePages = true
        replies = [:]
        expandedCommentIds = []
        await loadNextPage(replacing: true)
    }

    func loadMoreIfNeeded(current comment: CommentResponse) async {
        guard comment.id == comments.last?.id else { return }
        await loadNextPage(replacing: false)
    }

    private func loadNextPage(replacing: Bool) async {
        guard !isLoading, hasMorePages else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await commentService.fetchComments(diaryId: diaryId, page: currentPage, size: Self.pageSize)
            commentCount = response.commentCount
            if replacing {
                comments = response.comments.content
            } else {
                let existing = Set(comments.map(\.id))
                comments += response.comments.content.filter { !existing.contains($0.id) }
            }
            currentPage += 1
            hasMorePages = currentPage < response.comments.page.totalPages
        } catch {
            show(error)
        }
    }

    // MARK: - 답글 (reply_003)

    func toggleReplies(of comment: CommentResponse) async {
        if expandedCommentIds.contains(comment.id) {
            expandedCommentIds.remove(comment.id)
            return
        }
        expandedCommentIds.insert(comment.id)
        await loadReplies(of: comment.id)
    }

    private func loadReplies(of commentId: Int) async {
        guard !loadingReplyIds.contains(commentId) else { return }
        loadingReplyIds.insert(commentId)
        defer { loadingReplyIds.remove(commentId) }

        do {
            let response = try await commentService.fetchReplies(commentId: commentId, page: 0, size: Self.replyPageSize)
            replies[commentId] = response.content
        } catch {
            expandedCommentIds.remove(commentId)
            show(error)
        }
    }

    // MARK: - 입력 모드 (com_005, 수정)

    func startReply(to comment: CommentResponse) {
        guard let author = comment.author, let name = author.username, !name.isEmpty else { return }
        let parentId = comment.parentCommentId ?? comment.id
        inputMode = .reply(parentCommentId: parentId, targetName: name)
        mentionCandidates = [CommentMentionCandidate(userId: author.userId, name: name)]
        draft = "@\(name) "
    }

    func startEdit(_ comment: CommentResponse) {
        inputMode = .edit(comment: comment)
        mentionCandidates = CommentMention.candidates(from: comment)
        draft = comment.text ?? ""
    }

    func cancelInputMode() {
        inputMode = .normal
        mentionCandidates = []
        draft = ""
    }

    // MARK: - 등록 (reply_005)

    /// 성공하면 true (키보드 내림은 뷰에서)
    func submit() async -> Bool {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSubmitting else { return false }
        isSubmitting = true
        defer { isSubmitting = false }

        let references = CommentMention.references(in: text, candidates: mentionCandidates)
        let mode = inputMode

        do {
            switch mode {
            case .normal:
                let created = try await commentService.createComment(
                    diaryId: diaryId,
                    request: CommentWriteRequest(text: text, parentCommentId: nil, references: references.isEmpty ? nil : references)
                )
                comments.insert(created, at: 0)
                commentCount += 1
                scrollTargetId = created.id

            case .reply(let parentId, _):
                let created = try await commentService.createComment(
                    diaryId: diaryId,
                    request: CommentWriteRequest(text: text, parentCommentId: parentId, references: references.isEmpty ? nil : references)
                )
                if replies[parentId] == nil, expandedCommentIds.contains(parentId) == false {
                    // 펼친 적 없는 원댓글이면 기존 답글까지 불러와서 펼친다
                    expandedCommentIds.insert(parentId)
                    await loadReplies(of: parentId)
                } else {
                    expandedCommentIds.insert(parentId)
                    replies[parentId, default: []].append(created)
                }
                updateComment(id: parentId) { $0.replyCount += 1 }
                scrollTargetId = created.id

            case .edit(let original):
                // 수정은 references 전체 교체 → 빈 배열이면 멘션 제거
                let updated = try await commentService.updateComment(
                    commentId: original.id,
                    request: CommentWriteRequest(text: text, parentCommentId: nil, references: references)
                )
                updateComment(id: original.id) { $0 = updated }
            }
            cancelInputMode()
            return true
        } catch {
            // 실패 시 작성 내용 유지하지 않음 (명세)
            cancelInputMode()
            show(error)
            return false
        }
    }

    // MARK: - 좋아요 (com_004)

    func toggleLike(_ comment: CommentResponse) async {
        let original = comment
        updateComment(id: comment.id) {
            $0.isLiked.toggle()
            $0.likeCount = max($0.likeCount + ($0.isLiked ? 1 : -1), 0)
        }
        do {
            let response = try await commentService.toggleLike(commentId: comment.id)
            updateComment(id: comment.id) {
                $0.isLiked = response.isLiked
                $0.likeCount = response.likeCount
            }
        } catch {
            updateComment(id: comment.id) { $0 = original }
            show(error)
        }
    }

    // MARK: - 더보기 (com_006)

    func delete(_ comment: CommentResponse) async {
        do {
            try await commentService.deleteComment(commentId: comment.id)
            if let parentId = comment.parentCommentId {
                replies[parentId]?.removeAll { $0.id == comment.id }
                updateComment(id: parentId) { $0.replyCount = max($0.replyCount - 1, 0) }
                // 삭제 플레이스홀더의 마지막 답글이 지워지면 원댓글 자리도 사라진다
                if let parent = comments.first(where: { $0.id == parentId }), parent.isDeleted, parent.replyCount == 0 {
                    comments.removeAll { $0.id == parentId }
                }
            } else {
                if comment.replyCount > 0 {
                    updateComment(id: comment.id) { $0 = $0.asDeletedPlaceholder() }
                } else {
                    comments.removeAll { $0.id == comment.id }
                }
                commentCount = max(commentCount - 1, 0)
            }
            if case .edit(let editing) = inputMode, editing.id == comment.id {
                cancelInputMode()
            }
        } catch {
            show(error)
        }
    }

    /// 성공하면 true
    func report(commentId: Int, content: String) async -> Bool {
        do {
            try await commentService.reportComment(commentId: commentId, content: content)
            return true
        } catch {
            show(error)
            return false
        }
    }

    /// 차단/차단 해제 후 서버 마스킹 상태를 다시 받는다
    func block(userId: Int) async {
        do {
            try await userService.blockUser(blockedId: userId)
            await loadInitial()
        } catch {
            show(error)
        }
    }

    func unblock(userId: Int) async {
        do {
            try await userService.unblockUser(blockedId: userId)
            await loadInitial()
        } catch {
            show(error)
        }
    }

    // MARK: - Helpers

    private func updateComment(id: Int, _ change: (inout CommentResponse) -> Void) {
        if let index = comments.firstIndex(where: { $0.id == id }) {
            change(&comments[index])
            return
        }
        for parentId in replies.keys {
            if let index = replies[parentId]?.firstIndex(where: { $0.id == id }) {
                change(&replies[parentId]![index])
                return
            }
        }
    }

    private func show(_ error: Error) {
        if error is CancellationError { return }
        let message = (error as? LocalizedError)?.errorDescription ?? ""
        // 400 유효성 실패는 fieldErrors JSON 이 그대로 올 수 있어 일반 문구로 대체
        errorMessage = message.isEmpty || message.hasPrefix("{") ? "요청 처리에 실패했어요." : message
    }
}
