import SwiftUI
import PhotosUI
import UIKit

struct MyCollectionProfileSettingsSection: View {
    @ObservedObject var viewModel: ProfileSettingViewModel
    let onBackTap: () -> Void
    let onAccountActionTap: () -> Void
    let onUserUpdated: (UserModel) -> Void

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isEditingTag = false
    @State private var originalTagDraft = ""
    @State private var keyboardBottomInset: CGFloat = 0
    @State private var tagValidationFeedback: TagValidationFeedback?
    @FocusState private var isTagFieldFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MyCollectionProfileSettingPageContainerView(
                        minHeight: max(
                            geometry.size.height - (AppSpacing.l + bottomSafeAreaPadding),
                            0
                        )
                    ) {
                        MyCollectionProfileSettingsHeaderView(onBackTap: onBackTap)
                        profileEditorCard

                        if let successMessage = viewModel.successMessage {
                            Text(successMessage)
                                .font(AppFont.paperlogy4Regular(size: 13))
                                .foregroundStyle(AppColors.primary600.opacity(0.95))
                        }

                        if let errorMessage = viewModel.errorMessage, !isEditingTag {
                            Text(errorMessage)
                                .font(AppFont.paperlogy4Regular(size: 13))
                                .foregroundStyle(.red.opacity(0.95))
                        }

                        Spacer(minLength: AppSpacing.m)

                        MyCollectionAccountActionButton(
                            isProcessing: viewModel.isProcessing,
                            action: onAccountActionTap
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.bottom, max(AppSpacing.l, bottomSafeAreaPadding))
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: selectedPhotoItem) { newItem in
                Task {
                    await handlePickedImage(newItem)
                    selectedPhotoItem = nil
                }
            }
            .onChange(of: viewModel.tagDraft) { _ in
                guard isEditingTag else { return }
                tagValidationFeedback = nil
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) {
                notification in
                keyboardBottomInset = resolvedKeyboardInset(from: notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardBottomInset = 0
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: keyboardBottomInset)
            }
            .animation(.easeOut(duration: 0.2), value: keyboardBottomInset)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var profileEditorCard: some View {
        let helper = tagHelperMessage

        return HStack(alignment: .top, spacing: AppSpacing.m) {
            MyCollectionProfileImageColumnView(
                selectedPhotoItem: $selectedPhotoItem,
                profileImageURL: viewModel.profileImageURL,
                isProcessing: viewModel.isProcessing
            ) {
                Task {
                    if let updatedUser = await viewModel.deleteProfileImage() {
                        onUserUpdated(updatedUser)
                    }
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text(viewModel.displayName)
                    .font(AppFont.paperlogy5Medium(size: 20))
                    .foregroundStyle(Color.kpPrimary)

                MyCollectionProfileTagSectionView(
                    displayTag: viewModel.displayTag,
                    isEditingTag: isEditingTag,
                    tagDraft: $viewModel.tagDraft,
                    isProcessing: viewModel.isProcessing,
                    isTagFieldFocused: $isTagFieldFocused,
                    helperMessage: helper?.text,
                    helperColor: helper?.color
                ) {
                    beginTagEditing()
                }

                if isEditingTag {
                    MyCollectionProfileTagEditActionRowView(
                        isProcessing: viewModel.isProcessing,
                        canSubmit: viewModel.canSubmitTagUpdate,
                        onCancel: cancelTagEditing
                    ) {
                        submitTagUpdate()
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func submitTagUpdate() {
        Task {
            if let updatedUser = await viewModel.updateTag() {
                onUserUpdated(updatedUser)
                isEditingTag = false
                isTagFieldFocused = false
                tagValidationFeedback = nil
            } else {
                updateTagValidationFeedback(from: viewModel.errorMessage)
            }
        }
    }

    private func handlePickedImage(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        do {
            guard let imageData = try await item.loadTransferable(type: Data.self) else {
                viewModel.errorMessage = "이미지를 불러오지 못했어요."
                viewModel.successMessage = nil
                return
            }
            if let updatedUser = await viewModel.updateProfileImage(with: imageData) {
                onUserUpdated(updatedUser)
            }
        } catch {
            viewModel.errorMessage = "이미지를 불러오지 못했어요."
            viewModel.successMessage = nil
        }
    }

    private func cancelTagEditing() {
        viewModel.tagDraft = originalTagDraft
        viewModel.errorMessage = nil
        viewModel.successMessage = nil
        tagValidationFeedback = nil
        isEditingTag = false
        isTagFieldFocused = false
    }

    private func beginTagEditing() {
        originalTagDraft = viewModel.tagDraft
        isEditingTag = true
        isTagFieldFocused = true
        tagValidationFeedback = nil
        viewModel.successMessage = nil
        viewModel.errorMessage = nil
    }

    private var tagHelperMessage: TagHelperMessage? {
        guard isEditingTag else { return nil }

        if let tagValidationFeedback {
            switch tagValidationFeedback {
            case .invalidFormat:
                return TagHelperMessage(
                    text: "30자 이내의 영문과 숫자, 특수문자([.],[_])로 조합해주세요.",
                    color: .red.opacity(0.95)
                )
            case .duplicate:
                return TagHelperMessage(
                    text: "이미 사용된 태그입니다.",
                    color: .red.opacity(0.95)
                )
            case .unavailable:
                return TagHelperMessage(
                    text: "사용할 수 없는 태그입니다.",
                    color: .red.opacity(0.95)
                )
            }
        }

        let normalizedTag = normalizedTag(from: viewModel.tagDraft)
        guard isTagFormatValid(normalizedTag) else {
            return TagHelperMessage(
                text: "30자 이내의 영문과 숫자, 특수문자([.],[_])로 조합해주세요.",
                color: .red.opacity(0.95)
            )
        }

        return TagHelperMessage(
            text: "사용 가능한 회원태그입니다!",
            color: .green.opacity(0.9)
        )
    }

    private func normalizedTag(from rawTag: String) -> String {
        let trimmed = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("@") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    private func isTagFormatValid(_ tag: String) -> Bool {
        guard (4...30).contains(tag.count) else { return false }
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_.")
        guard tag.rangeOfCharacter(from: allowedCharacters.inverted) == nil else { return false }
        guard !tag.hasPrefix("."), !tag.hasSuffix("."), !tag.contains("..") else { return false }
        return true
    }

    private func updateTagValidationFeedback(from message: String?) {
        let normalizedMessage = message?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        if normalizedMessage.contains("이미 존재")
            || normalizedMessage.contains("이미 사용")
            || normalizedMessage.contains("already")
        {
            tagValidationFeedback = .duplicate
            return
        }

        if normalizedMessage.contains("tag는")
            || normalizedMessage.contains("30")
            || normalizedMessage.contains("영문")
            || normalizedMessage.contains("소문자")
            || normalizedMessage.contains("연속")
            || normalizedMessage.contains("형식")
        {
            tagValidationFeedback = .invalidFormat
            return
        }

        tagValidationFeedback = .unavailable
    }

    private var bottomSafeAreaPadding: CGFloat {
        currentSafeAreaBottomInset() + AppSpacing.s
    }

    private func resolvedKeyboardInset(from notification: Notification) -> CGFloat {
        guard
            let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else {
            return 0
        }

        let screenHeight = UIScreen.main.bounds.height
        let rawOverlap = max(0, screenHeight - frame.minY)
        return max(rawOverlap - currentSafeAreaBottomInset(), 0)
    }

    private func currentSafeAreaBottomInset() -> CGFloat {
        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow })
        else {
            return 0
        }
        return keyWindow.safeAreaInsets.bottom
    }
}

private struct TagHelperMessage {
    let text: String
    let color: Color
}

private enum TagValidationFeedback {
    case invalidFormat
    case duplicate
    case unavailable
}
