import SwiftUI

struct MyCollectionEditProfileButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment:.center,spacing: 6) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.kpPrimary)

                Text("설정")
                    .font(AppFont.paperlogy5Medium(size: 14))
                    .foregroundStyle(Color.kpPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.s)
            .background(Color.kpGray700)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
