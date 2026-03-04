import SwiftUI

struct MainTabView: View {
    let onLogout: () -> Void
    @State private var selectedTab: MainRootTab = .my

    var body: some View {
        TabView(selection: $selectedTab) {
            MyTabView(onLogout: onLogout)
                .tabItem {
                    Label("MY", systemImage: "house")
                }
                .tag(MainRootTab.my)

            AddTabView()
                .tabItem {
                    Label("추가", systemImage: "plus.square")
                }
                .tag(MainRootTab.add)
        }
        .tint(AppColors.primary600)
        .preferredColorScheme(.dark)
        .toolbarColorScheme(.dark, for: .tabBar)
        .toolbarBackground(.black, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onReceive(NotificationCenter.default.publisher(for: .navigateToPlayKillingPart)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = .my
            }
        }
    }
}

private enum MainRootTab: Hashable {
    case my
    case add
}
