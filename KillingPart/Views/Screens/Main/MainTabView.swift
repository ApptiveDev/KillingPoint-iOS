import SwiftUI

struct MainTabView: View {
    let onLogout: () -> Void

    var body: some View {
        TabView {
            MyTabView(onLogout: onLogout)
                .tabItem {
                    Label("마이", systemImage: "person.fill")
                }

            AddTabView()
                .tabItem {
                    Label("추가", systemImage: "plus.circle.fill")
                }
        }
        .tint(AppColors.primary600)
    }
}
