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
    @FocusState private var isTagFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                MyCollectionProfileSettingsHeaderView(onBackTap: onBackTap)

                profileEditorCard

                if let successMessage = viewModel.successMessage {
                    Text(successMessage)
                        .font(AppFont.paperlogy4Regular(size: 13))
                        .foregroundStyle(AppColors.primary600.opacity(0.95))
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(AppFont.paperlogy4Regular(size: 13))
                        .foregroundStyle(.red.opacity(0.95))
                }

                MyCollectionAccountActionButton(
                    isProcessing: viewModel.isProcessing,
                    action: onAccountActionTap
                )
                .padding(.top, AppSpacing.s)
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                await handlePickedImage(newItem)
                selectedPhotoItem = nil
            }
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
        .padding(.bottom, AppSpacing.l)
    }

    private var profileEditorCard: some View {
        let currentProfileImageURL = viewModel.profileImageURL

        return HStack(alignment: .top, spacing: AppSpacing.m) {
            VStack(spacing: AppSpacing.xs) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    MyCollectionProfileImageView(
                        profileImageURL: currentProfileImageURL,
                        size: 92,
                        iconSize: 34
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isProcessing)

                Text("프로필 사진")
                    .font(AppFont.paperlogy5Medium(size: 13))
                    .foregroundStyle(Color.kpPrimary)

                Button {
                    Task {
                        if let updatedUser = await viewModel.deleteProfileImage() {
                            onUserUpdated(updatedUser)
                        }
                    }
                } label: {
                    Text("기본 이미지 변경")
                        .font(AppFont.paperlogy5Medium(size: 12))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, AppSpacing.s)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isProcessing)
            }

            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text(viewModel.displayName)
                    .font(AppFont.paperlogy3Light(size: 20))
                    .foregroundStyle(Color.kpPrimary)
                tagSection

                if isEditingTag {
                    HStack(spacing: AppSpacing.s) {
                        Spacer()

                        Button {
                            cancelTagEditing()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.72))
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isProcessing)

                        Button {
                            Task {
                                if let updatedUser = await viewModel.updateTag() {
                                    onUserUpdated(updatedUser)
                                    isEditingTag = false
                                    isTagFieldFocused = false
                                }
                            }
                        } label: {
                            if viewModel.isProcessing {
                                ProgressView()
                                    .tint(AppColors.primary600)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(AppColors.primary600)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.canSubmitTagUpdate)
                        .opacity(viewModel.canSubmitTagUpdate ? 1 : 0.45)
                    }
                    .padding(.top, 2)
                }
            }

            Spacer()
        }
        .padding(AppSpacing.m)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isEditingTag {
                HStack(spacing: 6) {
                    Text("@")
                        .font(AppFont.paperlogy3Light(size: 14))
                        .foregroundStyle(Color.kpPrimary)

                    TextField("태그를 입력해 주세요", text: $viewModel.tagDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(AppFont.paperlogy3Light(size: 14))
                        .foregroundStyle(Color.kpPrimary)
                        .focused($isTagFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            isTagFieldFocused = false
                        }
                }
                .padding(.horizontal, AppSpacing.s)
                .padding(.vertical, AppSpacing.xs)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.primary600.opacity(0.62), lineWidth: 1)
                }
            } else {
                HStack(spacing: 8) {
                    Text(viewModel.displayTag)
                        .font(AppFont.paperlogy6SemiBold(size: 15))
                        .foregroundStyle(Color.kpPrimary)

                    Button {
                        originalTagDraft = viewModel.tagDraft
                        isEditingTag = true
                        isTagFieldFocused = true
                        viewModel.successMessage = nil
                        viewModel.errorMessage = nil
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(6)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isProcessing)
                }
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
        isEditingTag = false
        isTagFieldFocused = false
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
