import SwiftUI

struct MyCollectionAccountActionButton: View {
    let isProcessing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("로그아웃/회원탈퇴")
                .font(AppFont.paperlogy5Medium(size: 15))
                .underline()
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, AppSpacing.xs)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
        .opacity(isProcessing ? 0.45 : 1)
    }
}
