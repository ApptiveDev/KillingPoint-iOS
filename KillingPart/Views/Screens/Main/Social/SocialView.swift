import SwiftUI

struct SocialView: View {
    @StateObject private var viewModel = SocialViewModel()
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
        .task(id: selectedTopTab) {
            guard selectedTopTab == .friend else { return }
            await viewModel.loadInitialDataIfNeeded()
        }
        .onChange(of: searchText) { query in
            Task {
                await viewModel.searchUsers(with: query)
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
            if viewModel.isSearching {
                searchedResultHeader
            } else {
                friendToggleTabs
            }
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

    private var searchedResultHeader: some View {
        Text("검색 결과 \(viewModel.searchedUserTotalCount.formatted())명")
            .font(AppFont.paperlogy4Regular(size: 12))
            .foregroundStyle(Color.white.opacity(0.8))
    }

    private var friendToggleTabs: some View {
        HStack(spacing: AppSpacing.s) {
            ForEach(SocialFriendSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFriendSection = section
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(section.title)
                            .font(AppFont.paperlogy5Medium(size: 13))
                            .foregroundStyle(.white)

                        Text("\(totalCountText(for: section))")
                            .font(AppFont.paperlogy4Regular(size: 12))
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
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
            VStack(spacing: AppSpacing.s) {
                if isCurrentSectionLoading {
                    ProgressView()
                        .tint(AppColors.primary600)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, AppSpacing.xl)
                } else if let errorMessage = viewModel.errorMessage, currentSectionUsers.isEmpty {
                    VStack(spacing: AppSpacing.s) {
                        Text(errorMessage)
                            .font(AppFont.paperlogy4Regular(size: 13))
                            .foregroundStyle(Color.white.opacity(0.8))
                            .multilineTextAlignment(.center)

                        Button("다시 시도") {
                            Task {
                                await viewModel.refreshCurrentList()
                            }
                        }
                        .font(AppFont.paperlogy5Medium(size: 13))
                        .foregroundStyle(AppColors.primary600)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppSpacing.xl)
                } else if currentSectionUsers.isEmpty {
                    Text("표시할 친구가 없어요.")
                        .font(AppFont.paperlogy4Regular(size: 13))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, AppSpacing.xl)
                } else {
                    LazyVStack(spacing: AppSpacing.s) {
                        ForEach(currentSectionUsers) { user in
                            NavigationLink {
                                SocialMyCollectionView(
                                    viewModel: viewModel.makeSocialMyCollectionViewModel(for: user)
                                )
                                .id(user.userId)
                            } label: {
                                friendRow(user)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                Task {
                                    await viewModel.loadMoreCurrentSectionIfNeeded(
                                        currentUserId: user.userId,
                                        isMyPickSection: selectedFriendSection == .myPick
                                    )
                                }
                            }
                        }
                    }
                    .padding(.top, AppSpacing.xs)

                    if isCurrentSectionLoadingMore {
                        ProgressView()
                            .tint(AppColors.primary600)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, AppSpacing.s)
                    }
                }
            }
            .padding(.bottom, AppSpacing.l)
        }
        .refreshable {
            await viewModel.refreshCurrentList()
        }
    }

    private func friendRow(_ user: SocialListUser) -> some View {
        HStack(spacing: AppSpacing.s) {
            if let profileImageURL = user.profileImageURL {
                AsyncImage(url: profileImageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty, .failure:
                        profilePlaceholder
                    @unknown default:
                        profilePlaceholder
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                profilePlaceholder
                    .frame(width: 40, height: 40)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(AppFont.paperlogy5Medium(size: 14))
                    .foregroundStyle(.white)

                Text(user.displayTag)
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

    private var profilePlaceholder: some View {
        Circle()
            .fill(Color.white.opacity(0.16))
            .overlay {
                Image(systemName: "person.fill")
                    .foregroundStyle(Color.white.opacity(0.7))
            }
    }

    private var currentSectionUsers: [SocialListUser] {
        viewModel.users(for: selectedFriendSection == .myPick)
    }

    private var isCurrentSectionLoading: Bool {
        viewModel.isLoading(for: selectedFriendSection == .myPick)
    }

    private var isCurrentSectionLoadingMore: Bool {
        viewModel.isLoadingMore(for: selectedFriendSection == .myPick)
    }

    private func totalCountText(for section: SocialFriendSection) -> String {
        viewModel.totalCount(for: section == .myPick).formatted()
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

#Preview {
    SocialView()
}
