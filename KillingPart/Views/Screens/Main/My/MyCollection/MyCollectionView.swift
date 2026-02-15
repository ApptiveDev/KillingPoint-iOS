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

                Text("내 피드")
                    .font(AppFont.paperlogy7Bold(size: 24))
                    .foregroundStyle(.white)

                Text("내가 기록한 킬링파트 피드를 모아보는 공간입니다.")
                    .font(AppFont.paperlogy4Regular(size: 15))
                    .foregroundStyle(.white.opacity(0.75))

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
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
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
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
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
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.kpGray600)
            .padding(6)
            .background(Color.black.opacity(0.45), in: Circle())
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
                .foregroundStyle(isLiked ? Color.kpPrimary : Color.kpGray300)
            Text("\(likeCount)")
                .foregroundStyle(Color.kpGray300)
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.45), in: Capsule())
    }

    private var profileCard: some View {
        HStack(spacing: AppSpacing.m) {
            profileImage(size: 56, iconSize: 22)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(viewModel.displayName)
                    .font(AppFont.paperlogy6SemiBold(size: 16))
                    .foregroundStyle(.white)

                Text(viewModel.displayTag)
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    screenMode = .profileSettings
                }
            } label: {
                Text("프로필 설정")
                    .font(AppFont.paperlogy5Medium(size: 13))
                    .foregroundStyle(.white)
                    .padding(.vertical, AppSpacing.xs)
                    .padding(.horizontal, AppSpacing.s)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.m)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
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
                profileImage(size: 92, iconSize: 34)

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
    private func profileImage(size: CGFloat, iconSize: CGFloat) -> some View {
        if let profileImageURL = viewModel.profileImageURL {
            AsyncImage(url: profileImageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty, .failure:
                    profileImagePlaceholder(size: size, iconSize: iconSize)
                @unknown default:
                    profileImagePlaceholder(size: size, iconSize: iconSize)
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            profileImagePlaceholder(size: size, iconSize: iconSize)
        }
    }

    private func profileImagePlaceholder(size: CGFloat, iconSize: CGFloat) -> some View {
        Circle()
            .fill(Color.white.opacity(0.12))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: iconSize))
                    .foregroundStyle(.white.opacity(0.9))
            }
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
