import SwiftUI

struct OnboardingSkipButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Text("건너뛰기")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}
