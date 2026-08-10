import SwiftUI
import UIKit

struct MyTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    let onLogout: () -> Void
    let isRootTabSelected: Bool
    let startupPayload: MainStartupPayload?
    @State private var selectedTab: MyTopTab = .playKillingPart
    @State private var tabTransitionDirection: Edge = .trailing
    @State private var analyticsSession = SubTabAnalyticsSession(parent: .my)
    @State private var hasEnteredRootForAnalytics = false
    private static var hasConfiguredSegmentedControlAppearance = false
    private let tabAnimation = Animation.interactiveSpring(
        response: 0.32,
        dampingFraction: 0.85,
        blendDuration: 0.1
    )

    var body: some View {
        NavigationStack {
            ZStack {
                KillingPartBackgroundView()

                VStack(spacing: AppSpacing.m) {
                    topToggleTabs

                    ZStack {
                        if selectedTab == .myCollection {
                            MyCollectionView(onSessionEnded: onLogout)
                                .transition(tabContentTransition)
                        } else if selectedTab == .playKillingPart {
                            PlayKillingPartView(
                                isParentActive: isRootTabSelected && selectedTab == .playKillingPart,
                                preloadedCollectionViewModel: startupPayload?.playCollectionViewModel
                            )
                                .transition(tabContentTransition)
                        } else {
                            MusicCalendarView()
                                .transition(tabContentTransition)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .clipped()
                }
                .padding(.horizontal, AppSpacing.m)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            guard isRootTabSelected else { return }
            let entryType: SubTabAnalyticsEntryType = hasEnteredRootForAnalytics ? .unknown : .appLaunch
            hasEnteredRootForAnalytics = true
            analyticsSession.begin(selectedTab.analyticsName, entryType: entryType)
        }
        .onDisappear {
            guard isRootTabSelected, scenePhase == .active else { return }
            analyticsSession.end(reason: .viewDisappear)
        }
        .onChange(of: isRootTabSelected) { isSelected in
            if isSelected {
                hasEnteredRootForAnalytics = true
                analyticsSession.begin(selectedTab.analyticsName, entryType: .tabEnter)
            } else {
                analyticsSession.end(reason: .tabChange)
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                guard isRootTabSelected else { return }
                hasEnteredRootForAnalytics = true
                analyticsSession.begin(selectedTab.analyticsName, entryType: .appForeground)
            } else {
                analyticsSession.end(reason: .appBackground)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToPlayKillingPart)) { _ in
            selectTab(.playKillingPart, entryType: .unknown)
        }
    }

    private var topToggleTabs: some View {
        Picker("마이 탭", selection: segmentedSelectionBinding) {
            ForEach(MyTopTab.allCases, id: \.self) { tab in
                Text(tab.title)
                    .font(AppFont.paperlogy4Regular(size: 11))
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
        .scaleEffect(x: 1, y: 1.08, anchor: .center)
        .onAppear {
            configureSegmentedControlFontIfNeeded()
        }
    }

    private var segmentedSelectionBinding: Binding<MyTopTab> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                selectTab(newTab, entryType: .userSelect)
            }
        )
    }

    private func selectTab(
        _ newTab: MyTopTab,
        entryType: SubTabAnalyticsEntryType
    ) {
        let previousIndex = selectedTab.order
        let nextIndex = newTab.order

        guard previousIndex != nextIndex else { return }

        tabTransitionDirection = nextIndex > previousIndex ? .trailing : .leading

        withAnimation(tabAnimation) {
            selectedTab = newTab
        }

        guard isRootTabSelected, scenePhase == .active else { return }
        analyticsSession.transition(to: newTab.analyticsName, entryType: entryType)
    }

    private var tabContentTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: tabTransitionDirection).combined(with: .opacity),
            removal: .move(edge: tabTransitionDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private func configureSegmentedControlFontIfNeeded() {
        guard !Self.hasConfiguredSegmentedControlAppearance else { return }
        Self.hasConfiguredSegmentedControlAppearance = true

        let fallbackFont = UIFont.systemFont(ofSize: 13, weight: .regular)
        let segmentFont = UIFont(name: "Paperlogy-4Regular", size: 13) ?? fallbackFont

        UISegmentedControl.appearance().setTitleTextAttributes(
            [.font: segmentFont],
            for: .normal
        )
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.font: segmentFont],
            for: .selected
        )
    }
}

private enum MyTopTab: CaseIterable {
    case myCollection
    case playKillingPart
    case musicCalendar

    var title: String {
        switch self {
        case .myCollection:
            return "내 컬렉션"
        case .playKillingPart:
            return "킬링파트 재생"
        case .musicCalendar:
            return "뮤직캘린더"
        }
    }

    var order: Int {
        switch self {
        case .myCollection:
            return 0
        case .playKillingPart:
            return 1
        case .musicCalendar:
            return 2
        }
    }

    var analyticsName: SubTabAnalyticsName {
        switch self {
        case .myCollection:
            return .collection
        case .playKillingPart:
            return .killingPartPlay
        case .musicCalendar:
            return .musicCalendar
        }
    }
}


#Preview {
    MyTabView(
        onLogout: {
            print("로그아웃")
        },
        isRootTabSelected: true,
        startupPayload: nil
    )
}
