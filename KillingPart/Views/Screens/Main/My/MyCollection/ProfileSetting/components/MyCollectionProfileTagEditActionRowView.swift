import SwiftUI

struct MyCollectionProfileTagEditActionRowView: View {
    let isProcessing: Bool
    let canSubmit: Bool
    let onCancel: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            Spacer()

            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)

            Button(action: onSubmit) {
                if isProcessing {
                    ProgressView()
                        .tint(AppColors.primary600)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(AppColors.primary600)
                }
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.45)
        }
        .padding(.top, 2)
    }
}
