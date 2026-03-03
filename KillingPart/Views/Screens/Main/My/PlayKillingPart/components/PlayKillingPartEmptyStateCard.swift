import SwiftUI

struct PlayKillingPartEmptyStateCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.08))
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .overlay {
                VStack(spacing: AppSpacing.s) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(AppColors.primary600)

                    Text("재생할 음악 다이어리가 없어요.")
                        .font(AppFont.paperlogy5Medium(size: 14))
                        .foregroundStyle(.white.opacity(0.76))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
    }
}
