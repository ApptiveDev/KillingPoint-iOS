import SwiftUI

struct MainTabView: View {
    let onLogout: () -> Void

    var body: some View {
        TabView {
            HomeTabView(onLogout: onLogout)
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }

            AddTabView()
                .tabItem {
                    Label("추가", systemImage: "plus.circle.fill")
                }
        }
        .tint(AppColors.primary600)
    }
}

private struct HomeTabView: View {
    let onLogout: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                Text("Home")
                    .font(AppFont.paperlogy7Bold(size: 28))

                Text("메인 홈 탭입니다. 실제 카드/피드 구성으로 확장하세요.")
                    .font(AppFont.paperlogy4Regular(size: 16))
                    .foregroundStyle(.secondary)

                PrimaryButton(title: "로그아웃") {
                    onLogout()
                }

                Spacer()
            }
            .padding(AppSpacing.l)
            .navigationTitle("홈")
        }
    }
}

private struct AddTabView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                Text("Add")
                    .font(AppFont.paperlogy7Bold(size: 28))

                Text("추가 탭입니다. 생성 플로우를 여기에 연결하세요.")
                    .font(AppFont.paperlogy4Regular(size: 16))
                    .foregroundStyle(.secondary)

                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.primary300)
                    .frame(height: 160)
                    .overlay {
                        Text("Create Content")
                            .font(AppFont.paperlogy6SemiBold(size: 16))
                    }

                Spacer()
            }
            .padding(AppSpacing.l)
            .navigationTitle("추가")
        }
    }
}
