import SwiftUI

struct SocialLoginIconButton<Icon: View>: View {
    let backgroundColor: Color
    let foregroundColor: Color
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void
    @ViewBuilder let icon: () -> Icon

    private let size: CGFloat = 56

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(backgroundColor)

                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                } else {
                    icon()
                        .foregroundStyle(foregroundColor)
                }
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
