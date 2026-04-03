import SwiftUI

struct SocialFeedPlaceholderView: View {
    var body: some View {
        VStack(spacing: AppSpacing.s) {
            Text("피드 섹션")
                .font(AppFont.paperlogy6SemiBold(size: 16))
                .foregroundStyle(.white)
            Text("추후 UI를 연결할 수 있도록 자리만 만들어 두었습니다.")
                .font(AppFont.paperlogy4Regular(size: 13))
                .foregroundStyle(Color.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, AppSpacing.l)
    }
}
