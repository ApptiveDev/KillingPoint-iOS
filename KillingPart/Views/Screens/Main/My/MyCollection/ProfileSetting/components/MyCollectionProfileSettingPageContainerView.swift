import SwiftUI

struct MyCollectionProfileSettingPageContainerView<Content: View>: View {
    let minHeight: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            content()
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(minHeight: max(minHeight, 0), alignment: .topLeading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }
}
