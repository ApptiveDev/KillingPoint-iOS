import SwiftUI

struct SocialTopToggleTabsView: View {
    @Binding var selectedTopTab: SocialTopTab

    var body: some View {
        Picker("소셜 상단 탭", selection: $selectedTopTab) {
            ForEach(SocialTopTab.allCases, id: \.self) { tab in
                Text(tab.title)
                    .font(AppFont.paperlogy4Regular(size: 11))
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
        .scaleEffect(x: 1, y: 1.08, anchor: .center)
    }
}
