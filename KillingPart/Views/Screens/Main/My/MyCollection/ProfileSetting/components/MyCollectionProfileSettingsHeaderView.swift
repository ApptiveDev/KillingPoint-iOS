import SwiftUI

struct MyCollectionProfileSettingsHeaderView: View {
    let onBackTap: () -> Void

    var body: some View {
        HStack {
            Text("프로필 설정")
                .font(AppFont.paperlogy5Medium(size: 20))
                .foregroundStyle(Color.kpPrimary)

            Spacer()

            Button(action: onBackTap) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20, weight: .semibold))
                }
                .foregroundStyle(Color.kpPrimary)
            }
            .buttonStyle(.plain)
        }
    }
}
