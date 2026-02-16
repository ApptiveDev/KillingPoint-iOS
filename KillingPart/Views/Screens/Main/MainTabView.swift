import SwiftUI

struct MainTabView: View {
    let onLogout: () -> Void

    var body: some View {
        TabView {
            MyTabView(onLogout: onLogout)
                .tabItem {
                    Label("MY", systemImage: "house")
                }

            AddTabView()
                .tabItem {
                    Label("추가", systemImage: "plus.square")
                }
        }
        .tint(AppColors.primary600)
        .preferredColorScheme(.dark)
        .toolbarColorScheme(.dark, for: .tabBar)
        .toolbarBackground(.black, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
