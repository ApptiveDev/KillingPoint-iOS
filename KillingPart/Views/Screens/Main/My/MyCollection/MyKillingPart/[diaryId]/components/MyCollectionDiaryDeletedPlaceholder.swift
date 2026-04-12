import SwiftUI

struct MyCollectionDiaryDeletedPlaceholder: View {
    var body: some View {
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
}
