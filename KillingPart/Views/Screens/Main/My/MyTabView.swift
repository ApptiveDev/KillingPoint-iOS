import SwiftUI

struct MyTabView: View {
    let onLogout: () -> Void
    @State private var selectedTab: MyTopTab = .myCollection
    @State private var tabTransitionDirection: Edge = .trailing
    @Namespace private var tabSelectionAnimation
    private let tabAnimation = Animation.interactiveSpring(
        response: 0.32,
        dampingFraction: 0.85,
        blendDuration: 0.1
    )

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                }
                .padding(.horizontal, AppSpacing.m)
                .padding(.top, AppSpacing.m)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var topToggleTabs: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(MyTopTab.allCases, id: \.self) { tab in
                Button {
                    let previousIndex = selectedTab.order
                    let nextIndex = tab.order

                    guard previousIndex != nextIndex else { return }

                    tabTransitionDirection = nextIndex > previousIndex ? .trailing : .leading

                    withAnimation(tabAnimation) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(AppFont.paperlogy6SemiBold(size: 14))
                        .foregroundStyle(selectedTab == tab ? Color.black : Color.kpGray400)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            Group {
                                if selectedTab == tab {
                                    RoundedRectangle(cornerRadius: 42)
                                        .fill(Color.white)
                                        .matchedGeometryEffect(
                                            id: "selected-tab-background",
                                            in: tabSelectionAnimation
                                        )
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 42)
                .fill(Color.white.opacity(0.05))
                .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 4)
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
