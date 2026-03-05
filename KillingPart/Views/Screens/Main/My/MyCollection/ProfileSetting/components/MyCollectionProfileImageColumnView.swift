import SwiftUI
import PhotosUI

struct MyCollectionProfileImageColumnView: View {
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let profileImageURL: URL?
    let isProcessing: Bool
    let onResetTap: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                MyCollectionProfileImageView(
                    profileImageURL: profileImageURL,
                    size: 92,
                    iconSize: 34
                )
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)

            Text("프로필 사진")
                .font(AppFont.paperlogy5Medium(size: 13))
                .foregroundStyle(Color.kpPrimary)

            Button(action: onResetTap) {
                Text("기본 이미지 변경")
                    .font(AppFont.paperlogy5Medium(size: 12))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, AppSpacing.s)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
        }
    }
}
