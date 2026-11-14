import SwiftUI

// MARK: - 댓글 바텀시트 (reply_001 ~ reply_005, 상태/예외 처리)

struct DiaryCommentSheet: View {
    @StateObject private var viewModel: DiaryCommentViewModel
    @State private var isInputFocused = false

    @State private var menuTarget: CommentResponse?
    @State private var deleteTarget: CommentResponse?
    @State private var reportTarget: CommentResponse?
    @State private var reportContent = ""
    @State private var reportErrorMessage: String?
    @State private var isReporting = false
    /// 긴 본문 [더보기]로 펼친 댓글 (재진입 시 초기화)
    @State private var expandedBodyIds: Set<Int> = []
    /// 첫 프레임엔 입력창(UITextView) 생성을 미뤄 시트가 바로 올라오게 한다
    @State private var isInputReady = false

    private static let pendingRowId = "pending-comment"

    init(diaryId: Int, initialCommentCount: Int, onCommentsChanged: @escaping () -> Void = {}) {
        let viewModel = DiaryCommentViewModel(diaryId: diaryId, initialCommentCount: initialCommentCount)
        viewModel.onCommentsChanged = onCommentsChanged
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .safeAreaInset(edge: .bottom) { inputBar }
        .background(Color.black)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color.black)
        .presentationCornerRadius(24)
        .task {
            isInputReady = true
            await viewModel.loadInitial()
        }
        .confirmationDialog("", isPresented: isPresented($menuTarget), titleVisibility: .hidden, presenting: menuTarget) { comment in
            menuButtons(for: comment)
        }
        .alert("댓글을 삭제할까요?", isPresented: isPresented($deleteTarget), presenting: deleteTarget) { comment in
            Button("삭제", role: .destructive) {
                Task { await viewModel.delete(comment) }
            }
            Button("취소", role: .cancel) {}
        }
        .alert("알림", isPresented: errorAlertBinding) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(item: $reportTarget) { comment in
            SocialDiaryReportSheet(
                reportReason: $reportContent,
                isSubmitting: isReporting,
                errorMessage: reportErrorMessage,
                onCancel: { reportTarget = nil },
                onSubmit: { submitReport(commentId: comment.id) }
            )
        }
    }

    // MARK: reply_001

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
                Text(DiaryCommentFormat.count(viewModel.commentCount))
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

    // MARK: 상태별 화면

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasLoaded {
            ProgressView()
                .controlSize(.large)
                .tint(AppColors.primary600)
                .padding(.top, 60)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else if viewModel.loadFailed && viewModel.comments.isEmpty {
            loadFailedView
        } else if viewModel.comments.isEmpty && viewModel.pendingComment == nil {
            stateMessage {
                Text("아직 댓글이 없어요.\n\n첫 반응을 남겨주세요!")
            }
        } else {
            commentList
        }
    }

    private var loadFailedView: some View {
        stateMessage {
            VStack(spacing: AppSpacing.l) {
                Text("댓글을 불러오지 못했어요")

                Button {
                    Task { await viewModel.loadInitial() }
                } label: {
                    Group {
                        if viewModel.isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Text("다시 시도")
                        }
                    }
                    .font(AppFont.paperlogy5Medium(size: 14))
                    .foregroundStyle(.black)
                    .frame(minWidth: 76, minHeight: 34)
                    .padding(.horizontal, AppSpacing.s)
                    .background(AppColors.primary600, in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)
            }
        }
    }

    private func stateMessage(@ViewBuilder _ message: () -> some View) -> some View {
        message()
            .font(AppFont.paperlogy5Medium(size: 15))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.top, 100)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: reply_002, reply_003

    private var commentList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    if let pending = viewModel.pendingComment, pending.parentCommentId == nil {
                        pendingRow(pending)
                    }

                    ForEach(viewModel.comments) { comment in
                        commentThread(comment)
                            .task { await viewModel.loadMoreIfNeeded(current: comment) }
                    }

                    if viewModel.loadMoreFailed {
                        Button("다시 시도") {
                            Task { await viewModel.retryLoadMore() }
                        }
                        .font(AppFont.paperlogy5Medium(size: 13))
                        .foregroundStyle(AppColors.primary600)
                        .frame(maxWidth: .infinity)
                    } else if viewModel.isLoading {
                        ProgressView()
                            .tint(AppColors.primary600)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.vertical, AppSpacing.l)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.scrollTargetId) { targetId in
                guard let targetId else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(targetId, anchor: .center)
                }
            }
            .onChange(of: viewModel.pendingComment) { pending in
                guard pending != nil else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(Self.pendingRowId, anchor: .center)
                }
            }
        }
    }

    private func commentThread(_ comment: CommentResponse) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            row(comment)

            if comment.replyCount > 0 || viewModel.pendingComment?.parentCommentId == comment.id {
                let isExpanded = viewModel.expandedCommentIds.contains(comment.id)

                if comment.replyCount > 0 {
                    Button {
                        Task { await viewModel.toggleReplies(of: comment) }
                    } label: {
                        HStack(spacing: AppSpacing.xs) {
                            Rectangle()
                                .fill(Color.white.opacity(0.8))
                                .frame(width: 28, height: 1)
                            Text(isExpanded ? "답글 숨기기" : "답글 \(comment.replyCount)개 보기")
                                .font(AppFont.paperlogy4Regular(size: 11))
                                .foregroundStyle(Color.kpGray300)
                            if viewModel.loadingReplyIds.contains(comment.id) {
                                ProgressView().controlSize(.mini).tint(Color.kpGray300)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 40 + AppSpacing.s)
                    .padding(.top, -6)
                }

                if isExpanded {
                    VStack(alignment: .leading, spacing: AppSpacing.m) {
                        ForEach(viewModel.replies[comment.id] ?? []) { reply in
                            row(reply)
                        }
                        if let pending = viewModel.pendingComment, pending.parentCommentId == comment.id {
                            pendingRow(pending)
                        }
                    }
                    .padding(.leading, 40 + AppSpacing.s)
                }
            }
        }
    }

    private func row(_ comment: CommentResponse) -> some View {
        DiaryCommentRow(
            comment: comment,
            isBodyExpanded: expandedBodyIds.contains(comment.id),
            onExpandBody: { expandedBodyIds.insert(comment.id) },
            onLikeTap: { Task { await viewModel.toggleLike(comment) } },
            onReplyTap: {
                viewModel.startReply(to: comment)
                isInputFocused = true
            },
            onMoreTap: { menuTarget = comment },
            onUnblockTap: {
                guard let userId = comment.author?.userId else { return }
                Task { await viewModel.unblock(userId: userId) }
            }
        )
        .modifier(TargetHighlight(isOn: viewModel.highlightedCommentId == comment.id))
        .id(comment.id)
    }

    /// 등록중... (흐리게, 조작 불가)
    private func pendingRow(_ pending: DiaryCommentViewModel.PendingComment) -> some View {
        DiaryCommentRow(
            comment: .pending(text: pending.text, author: viewModel.myUser),
            isPending: true,
            isBodyExpanded: true,
            onExpandBody: {},
            onLikeTap: {},
            onReplyTap: {},
            onMoreTap: {},
            onUnblockTap: {}
        )
        .opacity(0.5)
        .allowsHitTesting(false)
        .id(Self.pendingRowId)
    }

    // MARK: com_006

    @ViewBuilder
    private func menuButtons(for comment: CommentResponse) -> some View {
        if comment.isMine {
            Button("수정") {
                viewModel.startEdit(comment)
                isInputFocused = true
            }
            Button("삭제", role: .destructive) {
                deleteTarget = comment
            }
        } else if let userId = comment.author?.userId {
            Button("차단", role: .destructive) {
                Task { await viewModel.block(userId: userId) }
            }
            Button("신고", role: .destructive) {
                reportContent = ""
                reportErrorMessage = nil
                reportTarget = comment
            }
        }
        Button("취소", role: .cancel) {}
    }

    private func submitReport(commentId: Int) {
        isReporting = true
        Task {
            let isSuccess = await viewModel.report(commentId: commentId, content: reportContent)
            isReporting = false
            if isSuccess {
                reportTarget = nil
            } else {
                // 시트 위에서는 부모 alert 가 안 보이므로 신고 시트 안에 표시
                reportErrorMessage = viewModel.errorMessage
                viewModel.errorMessage = nil
            }
        }
    }

    // MARK: reply_004, reply_005, 멘션

    private var inputBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            mentionPanel
                .padding(.horizontal, AppSpacing.m)
                .padding(.trailing, 44 + AppSpacing.xs)

            if let modeLabel {
                HStack {
                    modeLabel
                        .font(AppFont.paperlogy4Regular(size: 12))
                    Spacer()
                    Button {
                        viewModel.cancelInputMode()
                        isInputFocused = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.kpGray300)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("취소")
                }
                .padding(.leading, AppSpacing.l)
                .padding(.trailing, AppSpacing.m)
                .padding(.top, 4)
            }

            HStack(alignment: .bottom, spacing: AppSpacing.xs) {
                inputField

                Button {
                    Task {
                        if await viewModel.submit() {
                            isInputFocused = false
                        }
                    }
                } label: {
                    Text("등록")
                        .font(AppFont.paperlogy6SemiBold(size: 14))
                        .foregroundStyle(.black)
                        .frame(width: 44, height: 38)
                        .background(AppColors.primary600, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canSubmit)
                .opacity(viewModel.canSubmit ? 1 : 0.5)
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.vertical, AppSpacing.xs)
        }
        .background(Color.black)
    }

    private var inputField: some View {
        ZStack(alignment: .topLeading) {
            if viewModel.draft.isEmpty {
                Text("댓글을 달아보세요!")
                    .font(AppFont.paperlogy4Regular(size: 15))
                    .foregroundStyle(.white.opacity(0.45))
                    .allowsHitTesting(false)
            }
            if isInputReady {
                CommentInputTextView(
                    text: $viewModel.draft,
                    isFocused: $isInputFocused,
                    requestedCursor: $viewModel.requestedCursor,
                    highlightRanges: viewModel.inputHighlightRanges,
                    maxLength: DiaryCommentViewModel.maxTextLength,
                    onCursorChange: { viewModel.inputChanged(cursor: $0) }
                )
            }
        }
        .frame(maxWidth: .infinity, minHeight: 18, alignment: .topLeading)
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, 10)
        .background(DiaryCommentColors.inputBackground, in: RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private var mentionPanel: some View {
        switch viewModel.mentionState {
        case .hidden:
            EmptyView()
        case .empty:
            mentionNotice("일치하는 유저가 없어요.")
        case .limitReached:
            mentionNotice("한 댓글에 최대 5명까지 언급할 수 있어요.")
        case .results(let keyword, let users):
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(users, id: \.userId) { user in
                        Button {
                            viewModel.selectMention(user)
                        } label: {
                            mentionRow(user, keyword: keyword)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 3 * 40 + 8)
            .fixedSize(horizontal: false, vertical: users.count <= 3)
            .padding(.bottom, 4)
        }
    }

    private func mentionRow(_ user: CommentAuthor, keyword: String) -> some View {
        HStack {
            Text(mentionTagText(user.tag ?? user.username ?? "", keyword: keyword))
                .font(AppFont.paperlogy4Regular(size: 15))
                .lineLimit(1)
            Spacer(minLength: AppSpacing.s)
            Text(user.username ?? "")
                .font(AppFont.paperlogy4Regular(size: 13))
                .foregroundStyle(Color.kpGray300)
                .lineLimit(1)
        }
        .padding(.horizontal, AppSpacing.m)
        .frame(height: 36)
        .background(DiaryCommentColors.inputBackground, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }

    /// "@" + 입력한 부분은 초록, 나머지는 흰색 (시안)
    private func mentionTagText(_ tag: String, keyword: String) -> AttributedString {
        var result = AttributedString("@" + tag)
        result.foregroundColor = .white
        if let range = result.range(of: "@" + keyword, options: [.caseInsensitive, .anchored]) {
            result[range].foregroundColor = AppColors.primary600
        } else if let atRange = result.range(of: "@") {
            result[atRange].foregroundColor = AppColors.primary600
        }
        return result
    }

    private func mentionNotice(_ text: String) -> some View {
        Text(text)
            .font(AppFont.paperlogy4Regular(size: 13))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.m)
            .frame(height: 36)
            .background(DiaryCommentColors.inputBackground, in: RoundedRectangle(cornerRadius: 6))
            .padding(.bottom, 4)
    }

    private var modeLabel: Text? {
        switch viewModel.inputMode {
        case .normal:
            return nil
        case .reply(_, _, let targetName):
            return Text(targetName).foregroundColor(AppColors.primary600)
                + Text(" 님에게 답글 다는 중...").foregroundColor(.white)
        case .edit:
            return Text("댓글 수정 중...").foregroundColor(.white)
        }
    }

    // MARK: Bindings

    private func isPresented<T>(_ item: Binding<T?>) -> Binding<Bool> {
        Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil && reportTarget == nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

/// 답글/수정 대상 댓글 회색 하이라이트 (가로 전체)
private struct TargetHighlight: ViewModifier {
    let isOn: Bool

    func body(content: Content) -> some View {
        content
            .padding(.vertical, isOn ? AppSpacing.s : 0)
            .padding(.horizontal, AppSpacing.l)
            .background(isOn ? Color.white.opacity(0.18) : Color.clear)
            .padding(.horizontal, -AppSpacing.l)
    }
}

private extension CommentResponse {
    /// 등록중 표시용 가짜 댓글
    static func pending(text: String, author: UserModel?) -> CommentResponse {
        let json: [String: Any] = [
            "commentId": -1,
            "text": text,
            "author": [
                "userId": author?.userId ?? 0,
                "username": author?.username ?? "",
                "profileImageUrl": author?.profileImageUrl ?? ""
            ]
        ]
        // ponytail: 멤버와이즈 init 대신 관대한 디코더 재사용 (필드 기본값 일관 유지)
        let data = (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
        return (try? JSONDecoder().decode(CommentResponse.self, from: data))!
    }
}

// MARK: - 댓글 항목 (com_001 ~ com_006)

private struct DiaryCommentRow: View {
    let comment: CommentResponse
    var isPending = false
    let isBodyExpanded: Bool
    let onExpandBody: () -> Void
    let onLikeTap: () -> Void
    let onReplyTap: () -> Void
    let onMoreTap: () -> Void
    let onUnblockTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.s) {
            DiaryCommentAvatar(url: DiaryCommentFormat.url(comment.author?.profileImageUrl), size: 40)

            if comment.isDeleted {
                placeholderText("삭제된 댓글입니다.")
            } else if comment.isBlocked {
                HStack(alignment: .firstTextBaseline) {
                    placeholderText("차단한 유저의 댓글입니다.")
                    Spacer()
                    Button("차단 해제", action: onUnblockTap)
                        .font(AppFont.paperlogy4Regular(size: 13))
                        .foregroundStyle(Color.kpGray300)
                        .buttonStyle(.plain)
                }
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 4) {
            // com_001, com_002
            HStack(spacing: AppSpacing.xs) {
                Text(comment.author?.username ?? "")
                    .font(AppFont.paperlogy7Bold(size: 14))
                    .foregroundStyle(.white)
                Text(timeText)
                    .font(AppFont.paperlogy4Regular(size: 11))
                    .foregroundStyle(Color.kpGray300)
            }

            // com_003
            CommentBodyText(
                text: DiaryCommentBodyFormatter.attributed(comment.text ?? "", references: comment.attachment.references),
                isExpanded: isBodyExpanded,
                onExpand: onExpandBody
            )

            // com_004 ~ com_006
            HStack(spacing: AppSpacing.s) {
                Button(action: onLikeTap) {
                    HStack(spacing: 2) {
                        Image(systemName: comment.isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 10))
                            .foregroundStyle(comment.isLiked ? Color.kpPrimary : .white)
                        Text(comment.likeCount.formatted())
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel(comment.isLiked ? "좋아요 취소" : "좋아요")

                Button("답글달기", action: onReplyTap)

                Button(action: onMoreTap) {
                    Image(systemName: "ellipsis")
                        .frame(width: 24, height: 20)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("더보기")
            }
            .buttonStyle(.plain)
            .font(AppFont.paperlogy4Regular(size: 11))
            .foregroundStyle(Color.kpGray300)
            .padding(.top, 2)
        }
    }

    /// 수정된 댓글은 시간 대신 "수정됨" (com_002)
    private var timeText: String {
        if isPending { return "등록중..." }
        if comment.isEdited { return "수정됨" }
        return CommentTimeFormatter.relativeText(from: comment.createDate)
    }

    private func placeholderText(_ text: String) -> some View {
        Text(text)
            .font(AppFont.paperlogy4Regular(size: 14))
            .foregroundStyle(.white)
            .padding(.top, 11)
    }
}

/// 3줄 넘으면 접고 [더보기] (com_003)
private struct CommentBodyText: View {
    private static let collapsedLineLimit = 3

    let text: AttributedString
    let isExpanded: Bool
    let onExpand: () -> Void
    @State private var isTruncated = false

    var body: some View {
        Text(text)
            .lineLimit(isExpanded ? nil : Self.collapsedLineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                // 전체 높이와 3줄 높이를 비교해 잘렸는지 판단
                GeometryReader { limited in
                    Text(text)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: limited.size.width, alignment: .leading)
                        .hidden()
                        .background(GeometryReader { full in
                            Color.clear.preference(
                                key: TruncationPreferenceKey.self,
                                value: full.size.height > limited.size.height + 1
                            )
                        })
                }
            }
            .onPreferenceChange(TruncationPreferenceKey.self) { isTruncated = $0 }
            .overlay(alignment: .bottomTrailing) {
                if isTruncated && !isExpanded {
                    Button("더보기", action: onExpand)
                        .font(AppFont.paperlogy4Regular(size: 13))
                        .foregroundStyle(Color.kpGray300)
                        .padding(.leading, AppSpacing.s)
                        .background(Color.black)
                        .buttonStyle(.plain)
                }
            }
            .font(AppFont.paperlogy4Regular(size: 14))
            .foregroundStyle(.white)
            .tint(AppColors.primary600)
    }
}

private struct TruncationPreferenceKey: PreferenceKey {
    static var defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

// MARK: - 본문 강조 (멘션·링크: 초록, 링크는 밑줄)

enum DiaryCommentBodyFormatter {
    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    static func attributed(_ text: String, references: [CommentReference]) -> AttributedString {
        var attributed = AttributedString(text)

        for nsRange in CommentMention.highlightRanges(in: text, references: references) {
            if let range = attributedRange(nsRange, text: text, in: attributed) {
                attributed[range].foregroundColor = AppColors.primary600
            }
        }

        let fullRange = NSRange(location: 0, length: text.utf16.count)
        linkDetector?.matches(in: text, range: fullRange).forEach { match in
            guard let url = match.url, let range = attributedRange(match.range, text: text, in: attributed) else { return }
            attributed[range].link = url
            attributed[range].underlineStyle = .single
        }
        return attributed
    }

    private static func attributedRange(_ nsRange: NSRange, text: String, in attributed: AttributedString) -> Range<AttributedString.Index>? {
        guard let stringRange = Range(nsRange, in: text) else { return nil }
        return Range(stringRange, in: attributed)
    }
}
