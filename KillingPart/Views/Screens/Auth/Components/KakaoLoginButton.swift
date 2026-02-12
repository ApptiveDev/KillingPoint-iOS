import SwiftUI

struct KakaoLoginButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                HStack(spacing: 4) {
                    Image("kakaoTalkBubble")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 19, height: 19)
                        .foregroundStyle(Color.black)

                    Text("카카오 로그인")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.85))
                        .lineLimit(1)
                }
                .padding(.horizontal, 20)

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(Color.black.opacity(0.85))
                            .padding(.trailing, 20)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .background(Color(hex: "#FEE500"))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}
