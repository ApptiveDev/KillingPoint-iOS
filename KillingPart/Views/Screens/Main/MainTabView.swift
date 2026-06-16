import SwiftUI
import UIKit

struct MainTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    let onLogout: () -> Void
    let startupPayload: MainStartupPayload?
    var deepLinkRequest: DeepLinkRequest? = nil
    var onDeepLinkRequestConsumed: (DeepLinkRequest) -> Void = { _ in }
    @State private var selectedTab: MainRootTab = .my
    @State private var randomRefreshTrigger = 0
    @StateObject private var socialViewModel = SocialViewModel()
    @StateObject private var socialFeedViewModel = FeedViewModel()
    @State private var activeSocialDeepLinkRequest: DeepLinkRequest?
    @State private var activeTabForAnalytics: MainRootTab = .my
    @State private var activeTabEnteredAt = Date()
    @State private var hasTrackedInitialTabSelection = false
    @State private var hasTrackedInactivePhaseStay = false

    var body: some View {
        TabView(selection: $selectedTab) {
            MyTabView(
                onLogout: onLogout,
                isRootTabSelected: selectedTab == .my,
                startupPayload: startupPayload
            )
                .tabItem {
                    Label("MY", systemImage: "house")
                }
                .tag(MainRootTab.my)

            RandomSearchView(
                isRootTabSelected: selectedTab == .random,
                refreshTrigger: randomRefreshTrigger
            )
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
                feedViewModel: socialFeedViewModel,
                deepLinkRequest: activeSocialDeepLinkRequest,
                onDeepLinkRequestConsumed: handleSocialDeepLinkRequestConsumed
            )
                .tabItem {
                    Label("소셜", systemImage: "person.2")
                }
                .tag(MainRootTab.social)

        }
        .background(
            MainTabBarSelectionObserver { selectedIndex, wasReselected in
                guard wasReselected else { return }
                guard MainRootTab(tabIndex: selectedIndex) == .random else { return }
                randomRefreshTrigger &+= 1
            }
        )
        .tint(AppColors.primary600)
        .preferredColorScheme(.dark)
        .toolbarColorScheme(.dark, for: .tabBar)
        .toolbarBackground(.black, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onAppear {
            trackInitialMainTabSelectionIfNeeded()
        }
        .onDisappear {
            guard scenePhase == .active else { return }
            trackMainTabStayedIfNeeded(endReason: "view_disappear")
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                hasTrackedInactivePhaseStay = false
                return
            }
            guard !hasTrackedInactivePhaseStay else { return }
            hasTrackedInactivePhaseStay = true
            trackMainTabStayedIfNeeded(endReason: "app_background")
        }
        .onChange(of: selectedTab) { tab in
            handleMainTabSelectionChanged(to: tab)
            guard tab == .random else { return }
            randomRefreshTrigger &+= 1
        }
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
        .task(id: deepLinkRequest?.id) {
            guard let deepLinkRequest else { return }
            routeByDeepLink(deepLinkRequest)
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

    private func routeByDeepLink(_ request: DeepLinkRequest) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedTab = .social
        }

        activeSocialDeepLinkRequest = request
    }

    private func handleSocialDeepLinkRequestConsumed(_ request: DeepLinkRequest) {
        if activeSocialDeepLinkRequest == request {
            activeSocialDeepLinkRequest = nil
        }
        onDeepLinkRequestConsumed(request)
    }

    private func trackInitialMainTabSelectionIfNeeded() {
        guard !hasTrackedInitialTabSelection else { return }
        hasTrackedInitialTabSelection = true
        activeTabForAnalytics = selectedTab
        activeTabEnteredAt = Date()

        AmplitudeClient.shared.track(
            eventType: "main_tab_selected",
            properties: [
                "tab": selectedTab.analyticsName,
                "previous_tab": "none"
            ]
        )
    }

    private func handleMainTabSelectionChanged(to tab: MainRootTab) {
        trackInitialMainTabSelectionIfNeeded()
        guard activeTabForAnalytics != tab else { return }

        let previousTab = activeTabForAnalytics
        trackMainTabStayedIfNeeded(endReason: "tab_change")
        AmplitudeClient.shared.track(
            eventType: "main_tab_selected",
            properties: [
                "tab": tab.analyticsName,
                "previous_tab": previousTab.analyticsName
            ]
        )

        activeTabForAnalytics = tab
        activeTabEnteredAt = Date()
    }

    private func trackMainTabStayedIfNeeded(endReason: String) {
        guard hasTrackedInitialTabSelection else { return }
        let stayDuration = Date().timeIntervalSince(activeTabEnteredAt)
        guard stayDuration > 0 else { return }

        let roundedDuration = (stayDuration * 100).rounded() / 100
        AmplitudeClient.shared.track(
            eventType: "main_tab_stayed",
            properties: [
                "tab": activeTabForAnalytics.analyticsName,
                "stay_duration_sec": roundedDuration,
                "end_reason": endReason
            ]
        )
        activeTabEnteredAt = Date()
    }
}

private enum MainRootTab: Hashable {
    case my
    case random
    case social
    case add

    var tabIndex: Int {
        switch self {
        case .my:
            return 0
        case .random:
            return 1
        case .add:
            return 2
        case .social:
            return 3
        }
    }

    init?(tabIndex: Int) {
        switch tabIndex {
        case 0:
            self = .my
        case 1:
            self = .random
        case 2:
            self = .add
        case 3:
            self = .social
        default:
            return nil
        }
    }

    var analyticsName: String {
        switch self {
        case .my:
            return "my"
        case .random:
            return "explore"
        case .social:
            return "social"
        case .add:
            return "add"
        }
    }
}

private struct MainTabBarSelectionObserver: UIViewControllerRepresentable {
    let onDidSelect: (_ selectedIndex: Int, _ wasReselected: Bool) -> Void

    func makeUIViewController(context: Context) -> MainTabBarSelectionObserverViewController {
        let viewController = MainTabBarSelectionObserverViewController()
        viewController.coordinator = context.coordinator
        return viewController
    }

    func updateUIViewController(_ uiViewController: MainTabBarSelectionObserverViewController, context: Context) {
        context.coordinator.onDidSelect = onDidSelect
        uiViewController.coordinator = context.coordinator
        context.coordinator.attachIfNeeded(from: uiViewController)
    }

    static func dismantleUIViewController(_ uiViewController: MainTabBarSelectionObserverViewController, coordinator: Coordinator) {
        coordinator.detach()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDidSelect: onDidSelect)
    }

    final class Coordinator: NSObject, UITabBarControllerDelegate {
        var onDidSelect: (_ selectedIndex: Int, _ wasReselected: Bool) -> Void
        private weak var observedTabBarController: UITabBarController?
        private weak var forwardedDelegate: UITabBarControllerDelegate?
        private var lastSelectedIndex: Int?

        init(onDidSelect: @escaping (_ selectedIndex: Int, _ wasReselected: Bool) -> Void) {
            self.onDidSelect = onDidSelect
        }

        func attachIfNeeded(from hostViewController: UIViewController) {
            guard let tabBarController = hostViewController.enclosingTabBarController else { return }
            guard observedTabBarController !== tabBarController else { return }

            detach()

            lastSelectedIndex = tabBarController.selectedIndex
            forwardedDelegate = tabBarController.delegate === self ? nil : tabBarController.delegate
            observedTabBarController = tabBarController
            tabBarController.delegate = self
        }

        func detach() {
            guard let observedTabBarController else { return }
            if observedTabBarController.delegate === self {
                observedTabBarController.delegate = forwardedDelegate
            }
            self.observedTabBarController = nil
            self.forwardedDelegate = nil
            self.lastSelectedIndex = nil
        }

        deinit {
            detach()
        }

        func tabBarController(
            _ tabBarController: UITabBarController,
            shouldSelect viewController: UIViewController
        ) -> Bool {
            forwardedDelegate?.tabBarController?(tabBarController, shouldSelect: viewController) ?? true
        }

        func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
            let selectedIndex = tabBarController.selectedIndex
            let wasReselected = (selectedIndex == lastSelectedIndex)
            lastSelectedIndex = selectedIndex
            onDidSelect(selectedIndex, wasReselected)
            forwardedDelegate?.tabBarController?(tabBarController, didSelect: viewController)
        }
    }
}

private final class MainTabBarSelectionObserverViewController: UIViewController {
    weak var coordinator: MainTabBarSelectionObserver.Coordinator?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        coordinator?.attachIfNeeded(from: self)
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        coordinator?.attachIfNeeded(from: self)
    }
}

private extension UIViewController {
    var enclosingTabBarController: UITabBarController? {
        if let tabBarController {
            return tabBarController
        }

        var currentParent = parent
        while let candidate = currentParent {
            if let tabBarController = candidate as? UITabBarController {
                return tabBarController
            }
            currentParent = candidate.parent
        }

        if let rootViewController = view.window?.rootViewController {
            return rootViewController.firstDescendantTabBarController
        }

        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController?
            .firstDescendantTabBarController
    }

    var firstDescendantTabBarController: UITabBarController? {
        if let tabBarController = self as? UITabBarController {
            return tabBarController
        }

        for child in children {
            if let tabBarController = child.firstDescendantTabBarController {
                return tabBarController
            }
        }

        if let presentedViewController {
            return presentedViewController.firstDescendantTabBarController
        }

        return nil
    }
}
