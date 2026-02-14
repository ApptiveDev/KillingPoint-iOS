import SwiftUI

struct MyTabView: View {
    let onLogout: () -> Void
    @State private var selectedTab: MyTopTab = .myCollection

    var body: some View {
        NavigationStack {
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
            .navigationTitle("마이")
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
                        .foregroundStyle(selectedTab == tab ? Color.black : .secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.s)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    selectedTab == tab
                                        ? AppColors.primary300
                                        : Color(.secondarySystemBackground)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
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
