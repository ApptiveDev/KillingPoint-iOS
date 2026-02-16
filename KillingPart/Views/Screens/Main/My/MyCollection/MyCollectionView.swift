import SwiftUI

struct MyCollectionView: View {
    let onSessionEnded: () -> Void

    @StateObject private var viewModel: MyCollectionViewModel
    @State private var screenMode: MyCollectionScreenMode = .collectionList
    @State private var isAccountActionDialogPresented = false

    init(
        onSessionEnded: @escaping () -> Void,
        authenticationService: AuthenticationServicing = AuthenticationService(),
        userService: UserServicing = UserService(),
        diaryService: DiaryServicing = DiaryService()
    ) {
        self.onSessionEnded = onSessionEnded
        _viewModel = StateObject(
            wrappedValue: MyCollectionViewModel(
                authenticationService: authenticationService,
                userService: userService,
                diaryService: diaryService
            )
        )
    }

    var body: some View {
        Group {
            switch screenMode {
            case .collectionList:
                myFeedSection
            case .profileSettings:
                profileSettingsSection
            }
        }
        .confirmationDialog("계정", isPresented: $isAccountActionDialogPresented, titleVisibility: .visible) {
            Button("로그아웃", role: .destructive) {
                viewModel.logout(onSuccess: onSessionEnded)
            }
            Button("회원탈퇴", role: .destructive) {
                viewModel.deleteMyAccount(onSuccess: onSessionEnded)
            }
            Button("취소", role: .cancel) {}
        }
        .task {
            await viewModel.loadInitialDataIfNeeded()
        }
    }

    private var myFeedSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                profileCard

                if viewModel.myFeeds.isEmpty {
                    emptyFeedPlaceholder
                } else {
                    LazyVGrid(columns: feedGridColumns, spacing: AppSpacing.s) {
                        ForEach(viewModel.myFeeds) { feed in
                            feedCard(feed)
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(AppFont.paperlogy4Regular(size: 13))
                        .foregroundStyle(.red.opacity(0.95))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, AppSpacing.l)
        }
    }

    private var feedGridColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: AppSpacing.s),
            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: AppSpacing.s)
        ]
    }

    private var emptyFeedPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.08))
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .overlay {
                Text("아직 작성한 피드가 없어요.")
                    .font(AppFont.paperlogy5Medium(size: 14))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
    }

    private func feedCard(_ feed: DiaryFeedModel) -> some View {
        VStack(alignment: .center, spacing: AppSpacing.xs) {
            HStack {
                likeBadge(isLiked: feed.isLiked, likeCount: feed.likeCount)
                Spacer()
                scopeBadge(scope: feed.scope)
            }

            albumImage(url: feed.albumImageURL)

            Text(feed.musicTitle)
                .font(AppFont.paperlogy6SemiBold(size: 14))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(feed.artist)
                .font(AppFont.paperlogy4Regular(size: 13))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)

            Text(viewModel.formattedUpdateDate(from: feed.updateDate))
                .font(AppFont.paperlogy4Regular(size: 12))
                .foregroundStyle(Color.kpGray300)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.s)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func albumImage(url: URL?) -> some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty, .failure:
                    albumImagePlaceholder
                @unknown default:
                    albumImagePlaceholder
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            albumImagePlaceholder
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var albumImagePlaceholder: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.kpGray300)
            }
    }

    private func scopeBadge(scope: DiaryScope) -> some View {
        Image(systemName: scopeIconName(scope))
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(6)
    }

    private func scopeIconName(_ scope: DiaryScope) -> String {
        switch scope {
        case .private:
            return "lock.fill"
        case .public:
            return "globe.asia.australia.fill"
        case .killingPart:
            return "music.note"
        }
    }

    private func likeBadge(isLiked: Bool, likeCount: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .foregroundStyle(Color.kpPrimary)
            Text("\(likeCount)")
                .foregroundStyle(Color.kpGray300)
        }
        .font(.system(size: 13, weight: .semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }

    private var profileCard: some View {
        MyCollectionProfileCard(
            displayName: viewModel.displayName,
            displayTag: viewModel.displayTag,
            profileImageURL: viewModel.profileImageURL,
            killingPartStatText: viewModel.killingPartStatText,
            fanStatText: viewModel.fanStatText,
            pickStatText: viewModel.pickStatText
        ) {
            withAnimation(.easeInOut(duration: 0.2)) {
                screenMode = .profileSettings
            }
        }
    }

    private var profileSettingsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack {
                Text("프로필 설정")
                    .font(AppFont.paperlogy7Bold(size: 24))
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        screenMode = .collectionList
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("뒤로가기")
                            .font(AppFont.paperlogy5Medium(size: 13))
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, AppSpacing.xs)
                    .padding(.horizontal, AppSpacing.s)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: AppSpacing.m) {
                MyCollectionProfileImageView(
                    profileImageURL: viewModel.profileImageURL,
                    size: 92,
                    iconSize: 34
                )

                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    profileInfoRow(title: "이름", value: viewModel.displayName)
                    profileInfoRow(title: "아이디", value: viewModel.displayTag)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(AppSpacing.m)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(.red.opacity(0.95))
            }

            Button {
                guard !viewModel.isProcessing else { return }
                isAccountActionDialogPresented = true
            } label: {
                Text("로그아웃/회원탈퇴")
                    .font(AppFont.paperlogy5Medium(size: 15))
                    .underline()
                    .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
            }
            .disabled(viewModel.isProcessing)
            .padding(.top, AppSpacing.s)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.bottom, AppSpacing.l)
    }

    @ViewBuilder
    private func profileInfoRow(title: String, value: String) -> some View {
        HStack(spacing: AppSpacing.s) {
            Text(title)
                .font(AppFont.paperlogy5Medium(size: 14))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 48, alignment: .leading)

            Text(value)
                .font(AppFont.paperlogy5Medium(size: 14))
                .foregroundStyle(.white)
        }
        .padding(.vertical, AppSpacing.xs)
    }
}

private enum MyCollectionScreenMode {
    case collectionList
    case profileSettings
}
