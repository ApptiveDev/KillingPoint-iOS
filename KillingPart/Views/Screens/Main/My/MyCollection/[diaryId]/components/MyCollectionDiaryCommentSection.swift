import SwiftUI

struct MyCollectionDiaryCommentSection: View {
    let isEditMode: Bool
    let displayedContent: String
    @Binding var editContentDraft: String
    let isProcessing: Bool
    let canSubmitEdit: Bool
    let createdDateText: String
    let tagText: String
    let isCommentEditorFocused: FocusState<Bool>.Binding
    let onCancelTap: () -> Void
    let onSaveTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            if isEditMode {
                editCommentContainer
                editActionSection
            } else {
                readonlyCommentContainer
            }
        }
    }

    private var readonlyCommentContainer: some View {
        Text(displayedContent.isEmpty ? "작성된 코멘트가 없어요." : displayedContent)
            .font(AppFont.paperlogy4Regular(size: 14))
            .foregroundStyle(.white.opacity(0.92))
            .multilineTextAlignment(.leading)
            .lineSpacing(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.s)
            .padding(.top, 14)
            .padding(.bottom, 42)
            .frame(minHeight: 190, alignment: .topLeading)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
            .overlay(alignment: .bottomTrailing) {
                commentMetaSection
                    .padding(.trailing, AppSpacing.s)
                    .padding(.bottom, AppSpacing.xs)
            }
    }

    private var editCommentContainer: some View {
        TextEditor(text: $editContentDraft)
            .font(AppFont.paperlogy4Regular(size: 14))
            .foregroundColor(.white)
            .scrollContentBackground(.hidden)
            .focused(isCommentEditorFocused)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, AppSpacing.xs)
            .padding(.bottom, 34)
            .frame(minHeight: 190)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.primary600.opacity(0.92), lineWidth: 1.2)
            }
            .overlay(alignment: .bottomTrailing) {
                commentMetaSection
                    .padding(.trailing, AppSpacing.s)
                    .padding(.bottom, AppSpacing.xs)
            }
    }

    private var editActionSection: some View {
        HStack(spacing: AppSpacing.s) {
            Button(action: onCancelTap) {
                Text("취소")
                    .font(AppFont.paperlogy6SemiBold(size: 14))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
            .opacity(isProcessing ? 0.45 : 1)

            Button(action: onSaveTap) {
                HStack(spacing: 6) {
                    if isProcessing {
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
            .disabled(!canSubmitEdit)
            .opacity(canSubmitEdit ? 1 : 0.45)
        }
    }

    private var commentMetaSection: some View {
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
