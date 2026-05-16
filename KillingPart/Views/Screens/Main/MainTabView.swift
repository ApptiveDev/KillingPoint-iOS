import SwiftUI

struct MainTabView: View {
    let onLogout: () -> Void
    @State private var selectedTab: MainRootTab = .my
    @StateObject private var socialViewModel = SocialViewModel()
    @StateObject private var socialFeedViewModel = FeedViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            MyTabView(
                onLogout: onLogout,
                isRootTabSelected: selectedTab == .my
            )
                .tabItem {
                    Label("MY", systemImage: "house")
                }
                .tag(MainRootTab.my)

            RandomSearchView(isRootTabSelected: selectedTab == .random)
                .tabItem {
                    Label("탐색", systemImage: "waveform.path.ecg")
                }
                .tag(MainRootTab.random)

            AddTabView()
                .tabItem {
                    Label("추가", systemImage: "plus.square")
                }
                .tag(MainRootTab.add)
            
            SocialView(
                isRootTabSelected: selectedTab == .social,
                viewModel: socialViewModel,
                feedViewModel: socialFeedViewModel
            )
                .tabItem {
                    Label("소셜", systemImage: "person.2")
                }
                .tag(MainRootTab.social)

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
        .onReceive(NotificationCenter.default.publisher(for: .didTapPushAlarm)) { notification in
            guard let route = notification.object as? PushAlarmRoute else { return }
            FCMManager.shared.clearPendingAlarmRoute()
            routeByPushAlarm(route)
        }
        .task {
            guard let pendingRoute = FCMManager.shared.consumePendingAlarmRoute() else { return }
            routeByPushAlarm(pendingRoute)
        }
    }

    private func routeByPushAlarm(_ route: PushAlarmRoute) {
        print(
            "[PushRoute] MainTab route type=\(route.type.rawValue) deepLink=\(route.deepLink) alarmId=\(route.alarmId?.description ?? "nil")"
        )
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedTab = .social
        }

        Task { @MainActor in
            await socialViewModel.notificationListViewModel.handlePushAlarmRoute(route)
        }
    }
}

private enum MainRootTab: Hashable {
    case my
    case random
    case social
    case add
}
