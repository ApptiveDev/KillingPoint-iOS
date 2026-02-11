import SwiftUI

struct OnboardingNextButton: View {
    let action: () -> Void

    var body: some View {
        PrimaryButton(title: "다음") {
            action()
        }
    }
}
