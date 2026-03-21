import SwiftUI

struct KakaoLoginButton: View {
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        SocialLoginIconButton(
            backgroundColor: Color(hex: "#FEE500"),
            foregroundColor: .black,
            isLoading: isLoading,
            isDisabled: isDisabled,
            action: action
        ) {
            Image("kakaoTalkBubble")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 25, height: 25)
        }
        .accessibilityLabel("카카오 로그인")
    }
}
