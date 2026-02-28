import SwiftUI
import UIKit

struct MyCollectionDiary: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isCommentEditorFocused: Bool

    let diaryId: Int
    let onDiaryChanged: ((Int) -> Void)?
    @StateObject private var viewModel: MyCollectionDiaryViewModel
    @State private var isDeleteDialogPresented = false

    private let videoAspectRatio: CGFloat = 16 / 9
    private let videoCornerRadius: CGFloat = 16

    init(
        diaryId: Int,
        diary: DiaryFeedModel,
        onDiaryChanged: ((Int) -> Void)? = nil,
        diaryService: DiaryServicing = DiaryService()
    ) {
        self.diaryId = diaryId
        self.onDiaryChanged = onDiaryChanged
        _viewModel = StateObject(
            wrappedValue: MyCollectionDiaryViewModel(
                diary: diary,
                diaryService: diaryService
            )
        )
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isDeleted {
                deletedPlaceholder
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.m) {
                        videoSection
                        trackSection
                        commentSection
                        bottomMetaSection

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(AppFont.paperlogy4Regular(size: 13))
                                .foregroundStyle(.red.opacity(0.95))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.m)
                    .padding(.bottom, AppSpacing.l)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissKeyboard()
                    }
                }
                .scrollIndicators(.hidden)
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
            "일기를 삭제할까요?",
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
        }
    }

    private var videoSection: some View {
        YoutubePlayerView(
            videoURL: videoURL,
            startSeconds: viewModel.startSeconds,
            endSeconds: viewModel.endSeconds
        )
        .frame(maxWidth: .infinity)
        .aspectRatio(videoAspectRatio, contentMode: .fit)
        .allowsHitTesting(false)
        .clipShape(RoundedRectangle(cornerRadius: videoCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: videoCornerRadius)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var trackSection: some View {
        HStack(spacing: AppSpacing.m) {
            AddSearchDetailAlbumArtworkView(url: viewModel.diary.albumImageURL)
                .zIndex(2)

            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.diary.musicTitle)
                    .font(AppFont.paperlogy6SemiBold(size: 16))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(viewModel.diary.artist)
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)

                timelineRangeSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.m)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.15),
                    Color.white.opacity(0.02)
                ],
                startPoint: .trailing,
                endPoint: .leading
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var timelineRangeSection: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let startX = width * startProgress
            let endX = width * endProgress
            let segmentWidth = max(endX - startX, 2)
            let markerRadius: CGFloat = 3.5
            let startMarkerX = min(max(startX, markerRadius), width - markerRadius)
            let endMarkerX = min(max(endX, markerRadius), width - markerRadius)

            let labelY: CGFloat = 24

            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: width, height: 3)
                    .offset(y: 5)

                Capsule()
                    .fill(AppColors.primary600.opacity(0.95))
                    .frame(width: segmentWidth, height: 7)
                    .offset(x: startX, y: 3)

                Text(viewModel.startMinuteSecondText)
                    .font(AppFont.paperlogy6SemiBold(size: 10))
                    .foregroundStyle(AppColors.primary600.opacity(0.98))
                    .fixedSize()
                    .position(x: startX, y: labelY)

                Text(viewModel.endMinuteSecondText)
                    .font(AppFont.paperlogy5Medium(size: 10))
                    .foregroundStyle(AppColors.primary600.opacity(0.9))
                    .fixedSize()
                    .position(x: endX, y: labelY)
            }
        }
        .frame(height: 40)
    }

    private var commentSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("코멘트")
                .font(AppFont.paperlogy5Medium(size: 14))
                .foregroundStyle(.white.opacity(0.82))

            if viewModel.isEditMode {
                editCommentSection
            } else {
                Text(viewModel.displayedContent.isEmpty ? "작성된 코멘트가 없어요." : viewModel.displayedContent)
                    .font(AppFont.paperlogy4Regular(size: 14))
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.leading)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppSpacing.s)
                    .padding(.vertical, 14)
                    .frame(minHeight: 190, alignment: .topLeading)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }
            }
        }
    }

    private var editCommentSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            TextEditor(text: $viewModel.editContentDraft)
                .font(AppFont.paperlogy4Regular(size: 14))
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .focused($isCommentEditorFocused)
                .padding(.horizontal, AppSpacing.xs)
                .padding(.vertical, AppSpacing.xs)
                .padding(.bottom, AppSpacing.s)
                .frame(minHeight: 190)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }

            HStack(spacing: AppSpacing.s) {
                Button {
                    dismissKeyboard()
                    viewModel.cancelEdit()
                } label: {
                    Text("취소")
                        .font(AppFont.paperlogy6SemiBold(size: 14))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isProcessing)
                .opacity(viewModel.isProcessing ? 0.45 : 1)

                Button {
                    dismissKeyboard()
                    Task {
                        let isSuccess = await viewModel.submitEdit()
                        if isSuccess {
                            onDiaryChanged?(diaryId)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isProcessing {
                            ProgressView()
                                .tint(.black)
                        }
                        Text("수정 저장")
                            .font(AppFont.paperlogy6SemiBold(size: 14))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppColors.primary600)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canSubmitEdit)
                .opacity(viewModel.canSubmitEdit ? 1 : 0.45)
            }
        }
        .padding(AppSpacing.s)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var bottomMetaSection: some View {
        HStack(alignment: .bottom) {
            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                Text(createdDateText)
                    .font(AppFont.paperlogy4Regular(size: 12))
                    .foregroundStyle(.white.opacity(0.62))

                Text(tagText)
                    .font(AppFont.paperlogy5Medium(size: 13))
                    .foregroundStyle(.white.opacity(0.86))
            }
        }
    }

    private var deletedPlaceholder: some View {
        VStack(spacing: AppSpacing.s) {
            Image(systemName: "trash")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            Text("일기가 삭제되었어요.")
                .font(AppFont.paperlogy5Medium(size: 14))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, AppSpacing.l)
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
        let raw = (viewModel.diary.tag ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
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
