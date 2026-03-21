import SwiftUI

struct AppleLoginButton: View {
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        SocialLoginIconButton(
            backgroundColor: .black,
            foregroundColor: .white,
            isLoading: isLoading,
            isDisabled: isDisabled,
            action: action
        ) {
            Image(systemName: "applelogo")
                .font(.system(size: 24, weight: .semibold))
        }
        .overlay {
            Circle()
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        }
        .accessibilityLabel("애플 로그인")
    }
}
