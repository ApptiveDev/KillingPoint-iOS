import SwiftUI

struct OnboardingProgressView: View {
    let currentPage: Int

    var body: some View {
        Text("\(currentPage) / 5")
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
    }
}
