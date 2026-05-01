import SwiftUI

struct InitialSetupSkipButtonRow: View {
    let onSkip: () -> Void

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Button("건너뛰기") {
                onSkip()
            }
            .font(AppFont.paperlogy5Medium(size: 14))
            .foregroundStyle(.white.opacity(0.92))
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.top, AppSpacing.s)
        .padding(.bottom, AppSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
