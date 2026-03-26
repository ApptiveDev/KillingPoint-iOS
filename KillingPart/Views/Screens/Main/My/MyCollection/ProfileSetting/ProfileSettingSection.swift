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
            let bottomContentPadding = resolvedBottomContentPadding(
                safeAreaBottomInset: geometry.safeAreaInsets.bottom
            )
            let containerMinHeight = resolvedContainerMinHeight(
                availableHeight: geometry.size.height,
                bottomContentPadding: bottomContentPadding
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MyCollectionProfileSettingPageContainerView(
                        minHeight: containerMinHeight
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
                        .padding(.bottom, AppSpacing.xs)
                    }
                }
                .padding(.bottom, bottomContentPadding + keyboardBottomInset)
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
                applyKeyboardInset(from: notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) {
                notification in
                applyKeyboardInset(from: notification)
            }
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
                text: "4자 이상 30자 이내의 영문과 숫자, 특수문자([.],[_])로 조합해주세요.",
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

    private func resolvedBottomContentPadding(safeAreaBottomInset: CGFloat) -> CGFloat {
        let adaptiveInset = safeAreaBottomInset + AppSpacing.s
        if UIDevice.current.userInterfaceIdiom == .pad {
            return max(adaptiveInset, AppSpacing.l + AppSpacing.xl)
        }
        return max(AppSpacing.l, adaptiveInset)
    }

    private func resolvedContainerMinHeight(
        availableHeight: CGFloat,
        bottomContentPadding: CGFloat
    ) -> CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 0
        }

        let reservedBottomSpace = AppSpacing.l + bottomContentPadding + keyboardBottomInset
        return max(availableHeight - reservedBottomSpace, 0)
    }

    private func applyKeyboardInset(from notification: Notification) {
        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double)
            ?? 0.25
        let inset = resolvedKeyboardInset(from: notification)

        withAnimation(.easeOut(duration: duration)) {
            keyboardBottomInset = inset
        }
    }

    private func resolvedKeyboardInset(from notification: Notification) -> CGFloat {
        guard
            let userInfo = notification.userInfo,
            let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else {
            return 0
        }

        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)

        if let keyWindow {
            let endFrameInWindow = keyWindow.convert(endFrame, from: nil)
            return max(
                0,
                keyWindow.bounds.maxY - endFrameInWindow.minY - keyWindow.safeAreaInsets.bottom
            )
        }

        return max(0, UIScreen.main.bounds.maxY - endFrame.minY)
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
