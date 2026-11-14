import Foundation

@MainActor
final class DiaryCommentViewModel: ObservableObject {
    enum InputMode: Equatable {
        case normal
        /// parentCommentId 는 항상 원댓글 id (답글의 답글 없음), targetCommentId 는 누른 댓글(하이라이트용)
        case reply(parentCommentId: Int, targetCommentId: Int, targetName: String)
        case edit(comment: CommentResponse)
    }

    enum MentionState: Equatable {
        case hidden
        case results(keyword: String, users: [CommentAuthor])
        case empty
        case limitReached
    }

    /// 등록 응답 전까지 흐리게 보여줄 내 댓글
    struct PendingComment: Equatable {
        let text: String
        let parentCommentId: Int?
    }

    static let maxTextLength = 500
    private static let pageSize = 20
    // ponytail: 답글은 한 번에 최대 100개. 그 이상 달리는 경우가 생기면 페이지 더보기 추가
    private static let replyPageSize = 100
    private static let mentionSearchSize = 10

    let diaryId: Int

    @Published private(set) var commentCount: Int
    @Published private(set) var comments: [CommentResponse] = []
    @Published private(set) var replies: [Int: [CommentResponse]] = [:]
    @Published private(set) var expandedCommentIds: Set<Int> = []
    @Published private(set) var loadingReplyIds: Set<Int> = []
    @Published private(set) var isLoading = false
    /// 첫 목록 응답 전까지 전체 로딩 표시
    @Published private(set) var hasLoaded = false
    /// 첫 페이지 실패 → "댓글을 불러오지 못했어요" 화면
    @Published private(set) var loadFailed = false
    /// 다음 페이지 실패 → 목록 아래 [다시 시도]
    @Published private(set) var loadMoreFailed = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var pendingComment: PendingComment?
    @Published private(set) var myUser: UserModel?
    @Published private(set) var inputMode: InputMode = .normal
    @Published private(set) var mentionState: MentionState = .hidden
    @Published var draft = ""
    /// 입력창이 이 위치로 커서를 옮기고 nil 로 돌려놓는다 (멘션 선택 후)
    @Published var requestedCursor: Int?
    @Published var errorMessage: String?
    /// 등록 후 스크롤할 댓글 id
    @Published private(set) var scrollTargetId: Int?

    private var currentPage = 0
    private var hasMorePages = true
    private(set) var mentionCandidates: [CommentMentionCandidate] = []
    private var mentionQuery: (location: Int, keyword: String)?
    private var mentionSearchTask: Task<Void, Never>?

    /// 작성/수정/삭제 성공 시 호출 → 뒤 화면 refetch
    var onCommentsChanged: () -> Void = {}

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

    /// 답글/수정 대상 하이라이트
    var highlightedCommentId: Int? {
        switch inputMode {
        case .normal: return nil
        case .reply(_, let targetId, _): return targetId
        case .edit(let comment): return comment.id
        }
    }

    var inputHighlightRanges: [NSRange] {
        CommentMention.inputHighlightRanges(in: draft, candidates: mentionCandidates)
    }

    // MARK: - 목록

    func loadInitial() async {
        currentPage = 0
        hasMorePages = true
        replies = [:]
        expandedCommentIds = []
        loadFailed = false
        if myUser == nil {
            myUser = try? await userService.fetchMyUser()
        }
        await loadNextPage(replacing: true)
    }

    func loadMoreIfNeeded(current comment: CommentResponse) async {
        guard comment.id == comments.last?.id, !loadMoreFailed else { return }
        await loadNextPage(replacing: false)
    }

    func retryLoadMore() async {
        loadMoreFailed = false
        await loadNextPage(replacing: false)
    }

    private func loadNextPage(replacing: Bool) async {
        guard !isLoading, hasMorePages else { return }
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }

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
            hasMorePages = currentPage < response.comments.totalPages
        } catch is CancellationError {
            return
        } catch {
            // 실패는 알림 대신 화면 상태로 보여준다
            if replacing {
                loadFailed = true
            } else {
                loadMoreFailed = true
            }
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

    /// 본문 멘션은 태그(@goodmusic) 기준 (시안)
    func startReply(to comment: CommentResponse) {
        guard let author = comment.author else { return }
        let mentionName = author.tag ?? author.username ?? ""
        let displayName = author.username ?? mentionName
        guard !mentionName.isEmpty else { return }
        inputMode = .reply(
            parentCommentId: comment.parentCommentId ?? comment.id,
            targetCommentId: comment.id,
            targetName: displayName
        )
        mentionCandidates = [CommentMentionCandidate(userId: author.userId, name: mentionName)]
        setDraft("@\(mentionName) ")
    }

    func startEdit(_ comment: CommentResponse) {
        inputMode = .edit(comment: comment)
        mentionCandidates = CommentMention.candidates(from: comment)
        setDraft(comment.text ?? "")
    }

    func cancelInputMode() {
        inputMode = .normal
        mentionCandidates = []
        setDraft("")
    }

    private func setDraft(_ text: String) {
        draft = text
        requestedCursor = text.utf16.count
        hideMentions()
    }

    // MARK: - 멘션 검색 (08)

    /// 입력창의 텍스트/커서가 바뀔 때마다 호출
    func inputChanged(cursor: Int) {
        guard let query = CommentMention.activeQuery(in: draft, cursor: cursor) else {
            hideMentions()
            return
        }
        // 이미 확정된 멘션 위에 커서가 있는 경우는 검색하지 않는다
        if mentionCandidates.contains(where: { $0.name == query.keyword }) {
            hideMentions()
            return
        }
        mentionQuery = query

        let mentionedCount = CommentMention.references(in: draft, candidates: mentionCandidates).count
        if mentionedCount >= CommentMention.maxMentionUsers {
            mentionSearchTask?.cancel()
            mentionState = .limitReached
            return
        }

        mentionSearchTask?.cancel()
        mentionSearchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled, let self else { return }
            do {
                let users = try await commentService.fetchMentionCandidates(keyword: query.keyword, size: Self.mentionSearchSize)
                guard !Task.isCancelled, mentionQuery?.location == query.location else { return }
                mentionState = users.isEmpty ? .empty : .results(keyword: query.keyword, users: users)
            } catch {
                // 검색 실패 시 목록만 닫고 일반 텍스트로 입력
                hideMentions()
            }
        }
    }

    func selectMention(_ user: CommentAuthor) {
        guard let query = mentionQuery, let tag = user.tag ?? user.username, !tag.isEmpty else { return }
        let units = Array(draft.utf16)
        let end = query.location + 1 + query.keyword.utf16.count
        guard end <= units.count else { return }
        let inserted = "@\(tag) "
        let newText = String(decoding: units[..<query.location], as: UTF16.self)
            + inserted
            + String(decoding: units[end...], as: UTF16.self)
        guard newText.count <= Self.maxTextLength else { return }

        if !mentionCandidates.contains(where: { $0.userId == user.userId && $0.name == tag }) {
            mentionCandidates.append(CommentMentionCandidate(userId: user.userId, name: tag))
        }
        draft = newText
        requestedCursor = query.location + inserted.utf16.count
        hideMentions()
    }

    func hideMentions() {
        mentionSearchTask?.cancel()
        mentionQuery = nil
        mentionState = .hidden
    }

    // MARK: - 등록 (reply_005)

    /// 성공하면 true (키보드 내림은 뷰에서)
    func submit() async -> Bool {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSubmitting else { return false }

        let references = CommentMention.references(in: text, candidates: mentionCandidates)
        let mode = inputMode

        // 내용 변경 없는 수정은 요청하지 않고 종료
        if case .edit(let original) = mode, text == original.text {
            cancelInputMode()
            return true
        }

        isSubmitting = true
        hideMentions()
        defer {
            isSubmitting = false
            pendingComment = nil
        }

        do {
            switch mode {
            case .normal:
                pendingComment = PendingComment(text: text, parentCommentId: nil)
                cancelInputMode()
                let created = try await commentService.createComment(
                    diaryId: diaryId,
                    request: CommentWriteRequest(text: text, parentCommentId: nil, references: references.isEmpty ? nil : references)
                )
                if let created {
                    comments.insert(created, at: 0)
                    commentCount += 1
                    scrollTargetId = created.id
                } else {
                    await loadInitial()
                }

            case .reply(let parentId, _, _):
                expandedCommentIds.insert(parentId)
                pendingComment = PendingComment(text: text, parentCommentId: parentId)
                cancelInputMode()
                let created = try await commentService.createComment(
                    diaryId: diaryId,
                    request: CommentWriteRequest(text: text, parentCommentId: parentId, references: references.isEmpty ? nil : references)
                )
                // 답글은 서버 기준(오래된 순)으로 다시 불러와 펼친다
                await loadReplies(of: parentId)
                expandedCommentIds.insert(parentId)
                let loadedCount = replies[parentId]?.count
                updateComment(id: parentId) { $0.replyCount = loadedCount ?? $0.replyCount + 1 }
                scrollTargetId = created?.id ?? replies[parentId]?.last?.id

            case .edit(let original):
                // 수정은 references 전체 교체 → 빈 배열이면 멘션 제거
                let updated = try await commentService.updateComment(
                    commentId: original.id,
                    request: CommentWriteRequest(text: text, parentCommentId: nil, references: references)
                )
                updateComment(id: original.id) { $0 = updated }
                cancelInputMode()
            }
            onCommentsChanged()
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
            if highlightedCommentId == comment.id {
                cancelInputMode()
            }
            onCommentsChanged()
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
            onCommentsChanged()
        } catch {
            show(error)
        }
    }

    func unblock(userId: Int) async {
        do {
            try await userService.unblockUser(blockedId: userId)
            await loadInitial()
            onCommentsChanged()
        } catch {
            show(error)
        }
    }

    // MARK: - 멘션 탭 → 프로필

    /// 멘션 대상 유저를 찾는다. 본인 포함 항상 이동되도록 단계별로 찾는다
    func resolveMentionUser(userId: Int?, tag: String) async -> UserModel? {
        if myUser == nil {
            myUser = try? await userService.fetchMyUser()
        }
        if let me = myUser, me.userId == userId || me.tag.caseInsensitiveCompare(tag) == .orderedSame {
            return me
        }

        let matches: (Int, String) -> Bool = { candidateId, candidateTag in
            if let userId { return candidateId == userId }
            return candidateTag.caseInsensitiveCompare(tag) == .orderedSame
        }

        // 1) 유저 검색
        if let found = try? await userService.searchUsers(searchCond: tag, page: 0, size: 20).content
            .first(where: { matches($0.userId, $0.tag) }) {
            return found
        }
        // 2) 멘션 후보(내가 픽한 유저)
        if let author = try? await commentService.fetchMentionCandidates(keyword: tag, size: 20)
            .first(where: { matches($0.userId, $0.tag ?? "") }) {
            return UserModel(
                userId: author.userId,
                username: author.username ?? "",
                tag: author.tag ?? tag,
                identifier: "",
                profileImageUrl: author.profileImageUrl ?? "",
                userRoleType: "",
                socialType: ""
            )
        }
        // 3) 검색에 안 잡혀도 id 가 있으면 프로필 화면에서 나머지를 불러온다
        if let userId {
            return UserModel(userId: userId, username: "", tag: tag, identifier: "", profileImageUrl: "", userRoleType: "", socialType: "")
        }
        errorMessage = "사용자를 찾을 수 없어요."
        return nil
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
