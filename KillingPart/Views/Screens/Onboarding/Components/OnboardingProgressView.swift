import SwiftUI

struct OnboardingProgressView: View {
    let currentPage: Int

    var body: some View {
        Text("\(currentPage) / 5")
            .font(AppFont.paperlogy8ExtraBold(size: 16))
            .padding(16)
            .background(
                   RoundedRectangle(cornerRadius: 14, style: .continuous)
                       .fill(Color.kpGray600)
               )
            .foregroundStyle(Color.kpGray300)
    }
}
