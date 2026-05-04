import SwiftUI

struct GoogleLoginButton: View {
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        SocialLoginIconButton(
            backgroundColor: .white,
            foregroundColor: .black,
            isLoading: isLoading,
            isDisabled: isDisabled,
            action: action
        ) {
            Image("ic_google")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 24, height: 24)
        }
        .overlay {
            Circle()
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        }
        .accessibilityLabel("구글 로그인")
    }
}
