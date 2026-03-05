import SwiftUI
import PhotosUI

struct MyCollectionProfileSettingsSection: View {
    @ObservedObject var viewModel: ProfileSettingViewModel
    let onBackTap: () -> Void
    let onAccountActionTap: () -> Void
    let onUserUpdated: (UserModel) -> Void

    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            MyCollectionProfileSettingsHeaderView(onBackTap: onBackTap)

            MyCollectionProfileSettingsInfoCardView(
                displayName: viewModel.displayName,
                displayTag: viewModel.displayTag,
                profileImageURL: viewModel.profileImageURL
            )

            profileImageActionSection
            tagEditSection

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

            Spacer()
        }
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                await handlePickedImage(newItem)
                selectedPhotoItem = nil
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.bottom, AppSpacing.l)
    }

    private var profileImageActionSection: some View {
        HStack(spacing: AppSpacing.s) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.system(size: 12, weight: .semibold))
                    Text("이미지 변경")
                        .font(AppFont.paperlogy5Medium(size: 13))
                }
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, AppSpacing.s)
                .padding(.vertical, AppSpacing.xs)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(viewModel.isProcessing)

            Button {
                Task {
                    if let updatedUser = await viewModel.deleteProfileImage() {
                        onUserUpdated(updatedUser)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .semibold))
                    Text("기본 이미지")
                        .font(AppFont.paperlogy5Medium(size: 13))
                }
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, AppSpacing.s)
                .padding(.vertical, AppSpacing.xs)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isProcessing)

            Spacer()
        }
    }

    private var tagEditSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("아이디 변경")
                .font(AppFont.paperlogy5Medium(size: 14))
                .foregroundStyle(.white.opacity(0.82))

            HStack(spacing: 8) {
                Text("@")
                    .font(AppFont.paperlogy5Medium(size: 14))
                    .foregroundStyle(.white.opacity(0.9))

                TextField("태그를 입력해 주세요", text: $viewModel.tagDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(AppFont.paperlogy5Medium(size: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, AppSpacing.s)
            .padding(.vertical, AppSpacing.s)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }

            Button {
                Task {
                    if let updatedUser = await viewModel.updateTag() {
                        onUserUpdated(updatedUser)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isProcessing {
                        ProgressView()
                            .tint(.black)
                    }

                    Text("아이디 저장")
                        .font(AppFont.paperlogy6SemiBold(size: 14))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(AppColors.primary600)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSubmitTagUpdate)
            .opacity(viewModel.canSubmitTagUpdate ? 1 : 0.45)
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
}
