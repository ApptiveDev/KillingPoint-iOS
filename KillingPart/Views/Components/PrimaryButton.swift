import SwiftUI

struct PrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.s) {
                if isLoading {
                    ProgressView()
                        .tint(.black)
                }

                Text(title)
                    .font(AppFont.paperlogy6SemiBold(size: 16))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.m)
            .background(Color.kpPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .disabled(isLoading)
    }
}
