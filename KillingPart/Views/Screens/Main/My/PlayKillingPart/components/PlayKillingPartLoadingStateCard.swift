import SwiftUI

struct PlayKillingPartLoadingStateCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.08))
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .overlay {
                VStack(spacing: AppSpacing.s) {
                    ProgressView()
                        .tint(AppColors.primary600)
                    Text("재생 목록을 불러오는 중...")
                        .font(AppFont.paperlogy4Regular(size: 13))
                        .foregroundStyle(.white.opacity(0.74))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
    }
}
