import SwiftUI

// MARK: - 댓글 바텀시트 (reply_001 ~ reply_005)

struct DiaryCommentSheet: View {
    @StateObject private var viewModel: DiaryCommentViewModel
    @FocusState private var isInputFocused: Bool

    @State private var menuTarget: CommentResponse?
    @State private var deleteTarget: CommentResponse?
    @State private var reportTarget: CommentResponse?
    @State private var reportContent = ""
    @State private var reportErrorMessage: String?
    @State private var isReporting = false

    init(diaryId: Int, initialCommentCount: Int) {
        _viewModel = StateObject(
            wrappedValue: DiaryCommentViewModel(diaryId: diaryId, initialCommentCount: initialCommentCount)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            commentList
        }
        .safeAreaInset(edge: .bottom) { inputBar }
        .background(Color.black)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color.black)
        .presentationCornerRadius(24)
        .task { await viewModel.loadInitial() }
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

    // MARK: reply_002, reply_003

    private var commentList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(viewModel.comments) { comment in
                        commentThread(comment)
                            .task { await viewModel.loadMoreIfNeeded(current: comment) }
                    }

                    if viewModel.isLoading {
                        ProgressView()
                            .tint(AppColors.primary600)
                            .frame(maxWidth: .infinity)
                    } else if viewModel.comments.isEmpty {
                        Text("아직 댓글이 없어요.\n첫 댓글을 남겨보세요!")
                            .font(AppFont.paperlogy4Regular(size: 14))
                            .foregroundStyle(Color.kpGray300)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, AppSpacing.xl)
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
        }
    }

    private func commentThread(_ comment: CommentResponse) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            row(comment)

            if comment.replyCount > 0 {
                let isExpanded = viewModel.expandedCommentIds.contains(comment.id)

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

                if isExpanded {
                    VStack(alignment: .leading, spacing: AppSpacing.m) {
                        ForEach(viewModel.replies[comment.id] ?? []) { reply in
                            row(reply)
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
        .id(comment.id)
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

    // MARK: reply_004, reply_005

    private var inputBar: some View {
        VStack(spacing: 0) {
            if let modeText {
                HStack {
                    Text(modeText)
                        .font(AppFont.paperlogy4Regular(size: 12))
                        .foregroundStyle(Color.kpGray300)
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
                .padding(.horizontal, AppSpacing.m)
                .padding(.top, 4)
            }

            HStack(spacing: AppSpacing.xs) {
                TextField(
                    "",
                    text: $viewModel.draft,
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
                    Task {
                        if await viewModel.submit() {
                            isInputFocused = false
                        }
                    }
                } label: {
                    Group {
                        if viewModel.isSubmitting {
                            ProgressView().tint(.black)
                        } else {
                            Text("등록")
                                .font(AppFont.paperlogy6SemiBold(size: 14))
                        }
                    }
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 38)
                    .background(AppColors.primary600, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canSubmit)
                .opacity(viewModel.canSubmit || viewModel.isSubmitting ? 1 : 0.5)
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.vertical, AppSpacing.xs)
        }
        .background(Color.black)
    }

    private var modeText: String? {
        switch viewModel.inputMode {
        case .normal: return nil
        case .reply(_, let targetName): return "\(targetName)님에게 답글 다는 중..."
        case .edit: return "댓글 수정 중..."
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

// MARK: - 댓글 항목 (com_001 ~ com_006)

private struct DiaryCommentRow: View {
    let comment: CommentResponse
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
                VStack(alignment: .leading, spacing: 6) {
                    placeholderText("차단한 유저의 댓글입니다.")
                    Button("차단 해제", action: onUnblockTap)
                        .font(AppFont.paperlogy5Medium(size: 12))
                        .foregroundStyle(AppColors.primary600)
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
            Text(DiaryCommentBodyFormatter.attributed(comment.text ?? "", references: comment.attachment.references))
                .font(AppFont.paperlogy4Regular(size: 14))
                .foregroundStyle(.white)
                .tint(Color(hex: "#4DA3FF"))
                .fixedSize(horizontal: false, vertical: true)

            // com_004 ~ com_006
            HStack(spacing: AppSpacing.s) {
                Button(action: onLikeTap) {
                    HStack(spacing: 2) {
                        Image(systemName: comment.isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 10))
                            .foregroundStyle(comment.isLiked ? Color.kpPrimary : .white)
                        Text(comment.likeCount > 0 ? comment.likeCount.formatted() : "좋아요")
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

    private var timeText: String {
        let relative = CommentTimeFormatter.relativeText(from: comment.createDate)
        return comment.isEdited ? "\(relative) (수정됨)" : relative
    }

    private func placeholderText(_ text: String) -> some View {
        Text(text)
            .font(AppFont.paperlogy4Regular(size: 14))
            .foregroundStyle(Color.kpGray300)
            .padding(.top, 10)
    }
}

// MARK: - 본문 강조 (멘션: 초록, URL: 파란 링크)

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
