import SwiftUI

struct SocialView: View {
    @State private var selectedTopTab: SocialTopTab = .friend
    @State private var selectedFriendSection: SocialFriendSection = .myPick
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let bottomInset = min(geometry.safeAreaInsets.bottom, AppSpacing.xl) + AppSpacing.l

                ZStack {
                    Image("my_background")
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .ignoresSafeArea()

                    VStack(spacing: AppSpacing.m) {
                        topToggleTabs

                        if selectedTopTab == .friend {
                            friendSection
                        } else {
                            feedPlaceholder
                        }
                    }
                    .padding(.horizontal, AppSpacing.m)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.bottom, bottomInset)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar(.hidden, for: .navigationBar)
                .padding(.bottom, bottomInset)
            }
        }
    }

    private var topToggleTabs: some View {
        Picker("소셜 상단 탭", selection: $selectedTopTab) {
            ForEach(SocialTopTab.allCases, id: \.self) { tab in
                Text(tab.title)
                    .font(AppFont.paperlogy4Regular(size: 11))
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
        .scaleEffect(x: 1, y: 1.08, anchor: .center)
    }

    private var friendSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            searchBar
            friendToggleTabs
            friendList
        }
    }

    private var searchBar: some View {
        HStack(spacing: AppSpacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.white.opacity(0.75))

            TextField("친구 검색", text: $searchText)
                .font(AppFont.paperlogy4Regular(size: 14))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.m)
        .frame(height: 52)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        }
    }

    private var friendToggleTabs: some View {
        HStack(spacing: AppSpacing.s) {
            ForEach(SocialFriendSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFriendSection = section
                    }
                } label: {
                    Text(section.title)
                        .font(AppFont.paperlogy5Medium(size: 13))
                        .foregroundStyle(.white)
                        .padding(.vertical, AppSpacing.xs)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    selectedFriendSection == section
                                        ? AppColors.primary600.opacity(0.2)
                                        : Color.white.opacity(0.06)
                                )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    selectedFriendSection == section
                                        ? AppColors.primary600.opacity(0.8)
                                        : Color.white.opacity(0.2),
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(.plain)
                .opacity(selectedFriendSection == section ? 1 : 0.45)
            }
        }
    }

    private var friendList: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.s) {
                ForEach(filteredFriends, id: \.id) { friend in
                    friendRow(friend)
                }
            }
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.l)
        }
    }

    private func friendRow(_ friend: SocialFriendItem) -> some View {
        HStack(spacing: AppSpacing.s) {
            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "person.fill")
                        .foregroundStyle(Color.white.opacity(0.7))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(friend.name)
                    .font(AppFont.paperlogy5Medium(size: 14))
                    .foregroundStyle(.white)

                Text(friend.subtitle)
                    .font(AppFont.paperlogy4Regular(size: 12))
                    .foregroundStyle(Color.white.opacity(0.7))
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.s)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        }
    }

    private var filteredFriends: [SocialFriendItem] {
        let source = selectedFriendSection == .myPick ? SocialFriendItem.myPickSample : SocialFriendItem.myFandomSample
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else { return source }
        return source.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedQuery) ||
            $0.subtitle.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private var feedPlaceholder: some View {
        VStack(spacing: AppSpacing.s) {
            Text("피드 섹션")
                .font(AppFont.paperlogy6SemiBold(size: 16))
                .foregroundStyle(.white)
            Text("추후 UI를 연결할 수 있도록 자리만 만들어 두었습니다.")
                .font(AppFont.paperlogy4Regular(size: 13))
                .foregroundStyle(Color.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, AppSpacing.l)
    }
}

private enum SocialTopTab: CaseIterable {
    case feed
    case friend

    var title: String {
        switch self {
        case .feed:
            return "피드"
        case .friend:
            return "친구"
        }
    }
}

private enum SocialFriendSection: CaseIterable {
    case myPick
    case myFandom

    var title: String {
        switch self {
        case .myPick:
            return "나의 픽"
        case .myFandom:
            return "나의 팬덤"
        }
    }
}

private struct SocialFriendItem {
    let id: UUID = UUID()
    let name: String
    let subtitle: String

    static let myPickSample: [SocialFriendItem] = [
        .init(name: "@min_ji", subtitle: "재생목록 취향이 비슷한 친구"),
        .init(name: "@jun_note", subtitle: "최근 픽을 함께 저장했어요"),
        .init(name: "@yuna_daily", subtitle: "댓글로 자주 소통해요")
    ]

    static let myFandomSample: [SocialFriendItem] = [
        .init(name: "@starlight", subtitle: "같은 아티스트 팬덤"),
        .init(name: "@hypewave", subtitle: "팬덤 활동 점수 상위권"),
        .init(name: "@moonvibe", subtitle: "팬덤 피드 업데이트 활발")
    ]
}

#Preview {
    SocialView()
}
