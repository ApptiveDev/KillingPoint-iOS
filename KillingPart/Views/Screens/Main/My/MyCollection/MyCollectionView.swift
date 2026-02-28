import SwiftUI

struct MyCollectionView: View {
    let onSessionEnded: () -> Void

    @StateObject private var viewModel: MyCollectionViewModel
    @State private var screenMode: MyCollectionScreenMode = .collectionList
    @State private var navigationDirection: MyCollectionScreenTransitionDirection = .forward
    @State private var isAccountActionDialogPresented = false
    @State private var collectionListRenderID = UUID()

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
        ZStack {
            switch screenMode {
            case .collectionList:
                myFeedSection
                    .transition(screenTransition)
            case .profileSettings:
                profileSettingsSection
                    .transition(screenTransition)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: screenMode)
        .confirmationDialog("계정", isPresented: $isAccountActionDialogPresented, titleVisibility: .visible) {
            Button("로그아웃", role: .destructive) {
                viewModel.logout(onSuccess: onSessionEnded)
            }
            Button("회원탈퇴", role: .destructive) {
                viewModel.deleteMyAccount(onSuccess: onSessionEnded)
            }
            Button("취소", role: .cancel) {}
        }
        .onAppear {
            Task {
                await viewModel.refetchCollectionDataOnFocus()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .diaryCreated)) { _ in
            collectionListRenderID = UUID()
            Task {
                await viewModel.refetchCollectionDataOnFocus()
            }
        }
        .navigationDestination(for: MyCollectionDiaryRoute.self) { route in
            let diary = viewModel.myFeeds.first(where: { $0.diaryId == route.diaryId }) ?? route.initialDiary

            MyCollectionDiary(
                diaryId: route.diaryId,
                displayTag: viewModel.displayTag,
                diary: diary
            ) {
                collectionListRenderID = UUID()
                Task {
                    await viewModel.refetchCollectionDataOnFocus()
                }
            } onDiaryDeleted: { changedDiaryId in
                viewModel.removeMyFeedLocally(diaryId: changedDiaryId)
                collectionListRenderID = UUID()
                Task {
                    await viewModel.refetchCollectionDataOnFocus()
                }
            }
        }
    }

    private var screenTransition: AnyTransition {
        switch navigationDirection {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading),
                removal: .move(edge: .trailing)
            )
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
                            NavigationLink(
                                value: MyCollectionDiaryRoute(
                                    diaryId: feed.diaryId,
                                    initialDiary: feed
                                )
                            ) {
                                MyCollectionFeedCard(
                                    feed: feed,
                                    formattedUpdateDate: viewModel.formattedUpdateDate(from: feed.updateDate)
                                )
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                guard feed.id == viewModel.myFeeds.last?.id else { return }
                                Task {
                                    await viewModel.loadMoreMyFeedsFromBottomIfNeeded()
                                }
                            }
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("my-collection-bottom-trigger-\(viewModel.myFeeds.count)")
                        .onAppear {
                            Task {
                                await viewModel.loadMoreMyFeedsFromBottomIfNeeded()
                            }
                        }
                }

                if viewModel.isLoadingMoreFeeds {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(.white.opacity(0.88))
                        Spacer()
                    }
                    .padding(.top, AppSpacing.s)
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
        .id(collectionListRenderID)
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

    private var profileCard: some View {
        MyCollectionProfileCard(
            displayName: viewModel.displayName,
            displayTag: viewModel.displayTag,
            profileImageURL: viewModel.profileImageURL,
            killingPartStatText: viewModel.killingPartStatText,
            fanStatText: viewModel.fanStatText,
            pickStatText: viewModel.pickStatText
        ) {
            navigationDirection = .forward
            withAnimation(.easeInOut(duration: 0.2)) {
                screenMode = .profileSettings
            }
        }
    }

    private var profileSettingsSection: some View {
        MyCollectionProfileSettingsSection(
            displayName: viewModel.displayName,
            displayTag: viewModel.displayTag,
            profileImageURL: viewModel.profileImageURL,
            errorMessage: viewModel.errorMessage,
            isProcessing: viewModel.isProcessing
        ) {
            navigationDirection = .backward
            withAnimation(.easeInOut(duration: 0.2)) {
                screenMode = .collectionList
            }
        } onAccountActionTap: {
            guard !viewModel.isProcessing else { return }
            isAccountActionDialogPresented = true
        }
    }
}

private enum MyCollectionScreenMode {
    case collectionList
    case profileSettings
}

private enum MyCollectionScreenTransitionDirection {
    case forward
    case backward
}

private struct MyCollectionDiaryRoute: Hashable {
    let diaryId: Int
    let initialDiary: DiaryFeedModel

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.diaryId == rhs.diaryId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(diaryId)
    }
}
