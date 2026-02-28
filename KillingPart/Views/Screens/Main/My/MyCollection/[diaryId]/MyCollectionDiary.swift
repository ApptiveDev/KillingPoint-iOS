import SwiftUI
import UIKit

struct MyCollectionDiary: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isCommentEditorFocused: Bool

    let diaryId: Int
    let displayTag: String
    let onDiaryUpdated: (() -> Void)?
    let onDiaryDeleted: ((Int) -> Void)?
    @StateObject private var viewModel: MyCollectionDiaryViewModel
    @State private var isDeleteDialogPresented = false
    @State private var keyboardHeight: CGFloat = 0

    private let commentFocusAnchorID = "my-collection-diary-comment-focus-anchor"

    init(
        diaryId: Int,
        displayTag: String,
        diary: DiaryFeedModel,
        onDiaryUpdated: (() -> Void)? = nil,
        onDiaryDeleted: ((Int) -> Void)? = nil,
        diaryService: DiaryServicing = DiaryService()
    ) {
        self.diaryId = diaryId
        self.displayTag = displayTag
        self.onDiaryUpdated = onDiaryUpdated
        self.onDiaryDeleted = onDiaryDeleted
        _viewModel = StateObject(
            wrappedValue: MyCollectionDiaryViewModel(
                diary: diary,
                diaryService: diaryService
            )
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let topContentInset = min(proxy.safeAreaInsets.top, AppSpacing.l) + AppSpacing.s
            let bottomContentInset = proxy.safeAreaInsets.bottom + keyboardHeight + AppSpacing.l

            ZStack {
                Image("my_background")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea(.container, edges: .all)

                if viewModel.isDeleted {
                    MyCollectionDiaryDeletedPlaceholder()
                } else {
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: AppSpacing.m) {
                                MyCollectionDiaryVideoSection(
                                    videoURL: videoURL,
                                    startSeconds: viewModel.startSeconds,
                                    endSeconds: viewModel.endSeconds
                                )

                                MyCollectionDiaryTrackSection(
                                    artworkURL: viewModel.diary.albumImageURL,
                                    musicTitle: viewModel.diary.musicTitle,
                                    artist: viewModel.diary.artist,
                                    startMinuteSecondText: viewModel.startMinuteSecondText,
                                    endMinuteSecondText: viewModel.endMinuteSecondText,
                                    startProgress: startProgress,
                                    endProgress: endProgress
                                )

                                MyCollectionDiaryCommentSection(
                                    isEditMode: viewModel.isEditMode,
                                    displayedContent: viewModel.displayedContent,
                                    editContentDraft: $viewModel.editContentDraft,
                                    isProcessing: viewModel.isProcessing,
                                    canSubmitEdit: viewModel.canSubmitEdit,
                                    createdDateText: createdDateText,
                                    tagText: tagText,
                                    isCommentEditorFocused: $isCommentEditorFocused,
                                    onCancelTap: handleCancelTap,
                                    onSaveTap: handleSaveTap
                                )

                                if let errorMessage = viewModel.errorMessage {
                                    Text(errorMessage)
                                        .font(AppFont.paperlogy4Regular(size: 13))
                                        .foregroundStyle(.red.opacity(0.95))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                Color.clear
                                    .frame(height: 1)
                                    .id(commentFocusAnchorID)
                            }
                            .padding(.horizontal, AppSpacing.l)
                            .padding(.top, topContentInset)
                            .padding(.bottom, bottomContentInset)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                dismissKeyboard()
                            }
                        }
                        .scrollIndicators(.hidden)
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(of: isCommentEditorFocused) { isFocused in
                            guard isFocused else { return }
                            DispatchQueue.main.async {
                                withAnimation(.easeOut(duration: 0.22)) {
                                    scrollProxy.scrollTo(commentFocusAnchorID, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: keyboardHeight) { height in
                            guard isCommentEditorFocused else { return }
                            guard height > 0 else { return }
                            DispatchQueue.main.async {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    scrollProxy.scrollTo(commentFocusAnchorID, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            updateKeyboardHeight(from: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
            updateKeyboardHeight(from: notification)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    isDeleteDialogPresented = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.white)
                }
                .disabled(viewModel.isProcessing)
                .opacity(viewModel.isProcessing ? 0.45 : 1)

                Button {
                    viewModel.beginEdit()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(.white)
                }
                .disabled(viewModel.isEditMode || viewModel.isProcessing)
                .opacity((viewModel.isEditMode || viewModel.isProcessing) ? 0.45 : 1)
            }
        }
        .confirmationDialog(
            "일기 삭제",
            isPresented: $isDeleteDialogPresented,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                Task {
                    let isSuccess = await viewModel.deleteDiary()
                    if isSuccess {
                        onDiaryDeleted?(diaryId)
                        dismiss()
                    }
                }
            }
            .disabled(viewModel.isProcessing)

            Button("취소", role: .cancel) {}
        } message: {
            Text("일기를 삭제하시겠습니까? 삭제된 일기는 복구할 수 없습니다.")
        }
    }

    private var videoURL: URL? {
        let trimmed = viewModel.diary.videoUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let parsed = URL(string: trimmed), parsed.scheme != nil {
            return parsed
        }
        if trimmed.hasPrefix("//"), let parsed = URL(string: "https:\(trimmed)") {
            return parsed
        }
        return URL(string: "https://\(trimmed)")
    }

    private var startProgress: CGFloat {
        CGFloat(min(max(viewModel.startSeconds / viewModel.totalSeconds, 0), 1))
    }

    private var endProgress: CGFloat {
        CGFloat(
            min(
                max(viewModel.endSeconds / viewModel.totalSeconds, viewModel.startSeconds / viewModel.totalSeconds),
                1
            )
        )
    }

    private var createdDateText: String {
        let raw = viewModel.diary.createDate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "-" }
        let datePart = raw.split(separator: "T").first.map(String.init) ?? raw
        return datePart.replacingOccurrences(of: "-", with: ".")
    }

    private var tagText: String {
        let raw = displayTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "@killingpart_user" }
        return raw.hasPrefix("@") ? raw : "@\(raw)"
    }

    private func updateKeyboardHeight(from notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else {
            return
        }

        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)

        let overlapHeight: CGFloat
        if let keyWindow {
            let endFrameInWindow = keyWindow.convert(endFrame, from: nil)
            overlapHeight = max(
                0,
                keyWindow.bounds.maxY - endFrameInWindow.minY - keyWindow.safeAreaInsets.bottom
            )
        } else {
            overlapHeight = max(0, UIScreen.main.bounds.maxY - endFrame.minY)
        }

        let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        withAnimation(.easeOut(duration: duration)) {
            keyboardHeight = overlapHeight
        }
    }

    private func handleCancelTap() {
        dismissKeyboard()
        viewModel.cancelEdit()
    }

    private func handleSaveTap() {
        dismissKeyboard()
        Task {
            let isSuccess = await viewModel.submitEdit()
            guard isSuccess else { return }
            onDiaryUpdated?()
        }
    }

    private func dismissKeyboard() {
        isCommentEditorFocused = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
