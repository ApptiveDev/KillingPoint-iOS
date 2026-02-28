import SwiftUI
import UIKit

struct MyCollectionDiary: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isCommentEditorFocused: Bool

    let diaryId: Int
    let displayTag: String
    let onDiaryChanged: ((Int) -> Void)?
    @StateObject private var viewModel: MyCollectionDiaryViewModel
    @State private var isDeleteDialogPresented = false

    init(
        diaryId: Int,
        displayTag: String,
        diary: DiaryFeedModel,
        onDiaryChanged: ((Int) -> Void)? = nil,
        diaryService: DiaryServicing = DiaryService()
    ) {
        self.diaryId = diaryId
        self.displayTag = displayTag
        self.onDiaryChanged = onDiaryChanged
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
            let bottomContentInset = min(proxy.safeAreaInsets.bottom, AppSpacing.xl) + AppSpacing.l

            ZStack {
                Image("my_background")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()

                if viewModel.isDeleted {
                    MyCollectionDiaryDeletedPlaceholder()
                } else {
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
                                onCancelTap: {
                                    dismissKeyboard()
                                    viewModel.cancelEdit()
                                },
                                onSaveTap: {
                                    dismissKeyboard()
                                    Task {
                                        let isSuccess = await viewModel.submitEdit()
                                        guard isSuccess else { return }
                                    }
                                }
                            )

                            if let errorMessage = viewModel.errorMessage {
                                Text(errorMessage)
                                    .font(AppFont.paperlogy4Regular(size: 13))
                                    .foregroundStyle(.red.opacity(0.95))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
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
                }
            }
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
                        onDiaryChanged?(diaryId)
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
