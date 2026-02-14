import SwiftUI

struct MyTabView: View {
    let onLogout: () -> Void
    @State private var selectedTab: MyTopTab = .myCollection

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: AppSpacing.m) {
                    topToggleTabs

                    TabView(selection: $selectedTab) {
                        MyCollectionView(onSessionEnded: onLogout)
                            .tag(MyTopTab.myCollection)

                        PlayKillingPartView()
                            .tag(MyTopTab.playKillingPart)

                        MusicCalendarView()
                            .tag(MyTopTab.musicCalendar)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(AppFont.paperlogy6SemiBold(size: 14))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.s)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    selectedTab == tab
                                        ? AppColors.primary600.opacity(0.28)
                                        : Color.white.opacity(0.07)
                                )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    selectedTab == tab
                                        ? AppColors.primary600.opacity(0.85)
                                        : Color.white.opacity(0.12),
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 4)
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
}


#Preview {
    MyTabView(onLogout: {
        print("로그아웃")
    })
}
