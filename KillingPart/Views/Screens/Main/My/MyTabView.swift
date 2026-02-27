import SwiftUI

struct MyTabView: View {
    let onLogout: () -> Void
    @State private var selectedTab: MyTopTab = .myCollection
    @State private var tabTransitionDirection: Edge = .trailing
    private let tabAnimation = Animation.interactiveSpring(
        response: 0.32,
        dampingFraction: 0.85,
        blendDuration: 0.1
    )

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let bottomContentInset = min(geometry.safeAreaInsets.bottom, AppSpacing.xl) + AppSpacing.l

                ZStack {
                    Image("my_background")
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .ignoresSafeArea()

                    VStack(spacing: AppSpacing.m) {
                        topToggleTabs

                        ZStack {
                            if selectedTab == .myCollection {
                                MyCollectionView(onSessionEnded: onLogout)
                                    .transition(tabContentTransition)
                            } else if selectedTab == .playKillingPart {
                                PlayKillingPartView()
                                    .transition(tabContentTransition)
                            } else {
                                MusicCalendarView()
                                    .transition(tabContentTransition)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .clipped()
                        .padding(.bottom, bottomContentInset)
                    }
                    .padding(.horizontal, AppSpacing.m)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.bottom, bottomContentInset)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar(.hidden, for: .navigationBar)
                .padding(.bottom, bottomContentInset)
            }
        }
    }

    private var topToggleTabs: some View {
        Picker("마이 탭", selection: segmentedSelectionBinding) {
            ForEach(MyTopTab.allCases, id: \.self) { tab in
                Text(tab.title)
                    .font(AppFont.paperlogy6SemiBold(size: 16))
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
        .scaleEffect(x: 1, y: 1.08, anchor: .center)
        .padding(.vertical, AppSpacing.xs)
    }

    private var segmentedSelectionBinding: Binding<MyTopTab> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                let previousIndex = selectedTab.order
                let nextIndex = newTab.order

                guard previousIndex != nextIndex else { return }

                tabTransitionDirection = nextIndex > previousIndex ? .trailing : .leading

                withAnimation(tabAnimation) {
                    selectedTab = newTab
                }
            }
        )
    }

    private var tabContentTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: tabTransitionDirection).combined(with: .opacity),
            removal: .move(edge: tabTransitionDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
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
}


#Preview {
    MyTabView(onLogout: {
        print("로그아웃")
    })
}
