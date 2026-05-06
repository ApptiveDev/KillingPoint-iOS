import SwiftUI
import PhotosUI

struct ProfileImageEdit: View {
    @ObservedObject var viewModel: ProfileSettingViewModel
    let onUserUpdated: (UserModel) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            SettingsSubpageHeader(title: "프로필 이미지") {
                dismiss()
            }

            profileImageSection

            imageActionCard

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

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.top, AppSpacing.s)
        .background(
            LinearGradient(
                colors: [Color.black, Color(hex: "#10131B")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .onAppear {
            viewModel.errorMessage = nil
            viewModel.successMessage = nil
        }
        .onChange(of: selectedPhotoItem) { item in
            Task {
                await handlePickedImage(item)
                selectedPhotoItem = nil
            }
        }
        .navigationBarBackButtonHidden()
    }

    private var profileImageSection: some View {
        ZStack(alignment: .bottomTrailing) {
            MyCollectionProfileImageView(
                profileImageURL: viewModel.profileImageURL,
                size: 170,
                iconSize: 56
            )

            Circle()
                .fill(Color.black.opacity(0.8))
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                }
                .offset(x: 10, y: 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.s)
    }

    private var imageActionCard: some View {
        VStack(spacing: 0) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                SettingsNavigationRowLabel(title: "갤러리에서 선택")
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isProcessing)

            Divider()
                .background(Color.white.opacity(0.08))

            Button {
                Task {
                    if let updatedUser = await viewModel.deleteProfileImage() {
                        onUserUpdated(updatedUser)
                    }
                }
            } label: {
                SettingsNavigationRowLabel(title: "기본 이미지로 변경")
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isProcessing)
            .opacity(viewModel.isProcessing ? 0.45 : 1)
        }
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
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
