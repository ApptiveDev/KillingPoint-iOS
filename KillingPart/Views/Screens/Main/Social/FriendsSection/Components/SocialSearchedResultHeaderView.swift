import SwiftUI

struct SocialSearchedResultHeaderView: View {
    let totalCount: Int

    var body: some View {
        Text("검색 결과 \(totalCount.formatted())명")
            .font(AppFont.paperlogy4Regular(size: 12))
            .foregroundStyle(Color.white.opacity(0.8))
    }
}
