import SwiftUI

struct BlocklistView: View {
    @ObservedObject var viewModel: BlocklistViewModel

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool
    @State private var pendingUnblockUser: UserModel?

    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding = AppSpacing.l

            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    SettingsSubpageHeader(
                        title: "차단 목록",
                        titleColor: .white,
                        titleFontSize: 20,
                        backButtonColor: .white
                    ) {
                        dismiss()
                    }
                    .padding(.horizontal, horizontalPadding)

                    VStack(alignment: .leading, spacing: AppSpacing.m) {
                        Text("총 \(viewModel.totalBlockedUsers)명")
                            .font(AppFont.paperlogy4Regular(size: 14))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .center)

                        searchBar

                        listSection

                        Divider()
                            .background(Color.white.opacity(0.1))

                        Text("차단된 사용자는 회원님의 킬링파트 및 컬렉션을 확인할 수 없습니다.")
                            .font(AppFont.paperlogy4Regular(size: 12))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, AppSpacing.m)

                    Spacer(minLength: 0)
                }

                if let pendingUnblockUser {
                    unblockConfirmationSheet(
                        user: pendingUnblockUser,
                        safeAreaBottomInset: geometry.safeAreaInsets.bottom
                    )
                }
            }
        }
        .background(
            Color.black
                .ignoresSafeArea()
        )
        .navigationBarBackButtonHidden()
        .onAppear {
            Task {
                await viewModel.refresh()
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: AppSpacing.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.6))

            TextField("검색", text: $viewModel.searchText)
                .focused($isSearchFocused)
                .font(AppFont.paperlogy4Regular(size: 14))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.white.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.m)
        .frame(height: 52)
        .background(
            Color.white.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    @ViewBuilder
    private var listSection: some View {
        if viewModel.isLoadingInitial && viewModel.blockedUsers.isEmpty {
            HStack {
                Spacer()
                ProgressView()
                    .tint(AppColors.primary600)
                Spacer()
            }
            .padding(.top, AppSpacing.l)
        } else if let errorMessage = viewModel.errorMessage, viewModel.blockedUsers.isEmpty {
            VStack(spacing: AppSpacing.s) {
                Text(errorMessage)
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .multilineTextAlignment(.center)

                Button("다시 시도") {
                    Task {
                        await viewModel.refresh()
                    }
                }
                .font(AppFont.paperlogy5Medium(size: 13))
                .foregroundStyle(AppColors.primary600)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, AppSpacing.m)
        } else if viewModel.filteredBlockedUsers.isEmpty {
            Text(viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "차단한 사용자가 없어요." : "검색 결과가 없어요.")
                .font(AppFont.paperlogy4Regular(size: 13))
                .foregroundStyle(.white.opacity(0.62))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, AppSpacing.l)
        } else {
            ScrollView {
                LazyVStack(spacing: AppSpacing.s) {
                    ForEach(viewModel.filteredBlockedUsers) { user in
                        blockedUserRow(user)
                            .onAppear {
                                Task {
                                    await viewModel.loadMoreIfNeeded(currentUserId: user.userId)
                                }
                            }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .tint(AppColors.primary600)
                            .padding(.top, AppSpacing.s)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 300)
        }
    }

    private func blockedUserRow(_ user: UserModel) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.m) {
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(AppFont.paperlogy5Medium(size: 14))
                    .foregroundStyle(.white)

                Text(user.displayTag)
                    .font(AppFont.paperlogy4Regular(size: 12))
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer(minLength: 0)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    pendingUnblockUser = user
                }
                viewModel.clearUnblockError()
            } label: {
                Text("차단 해제")
                    .font(AppFont.paperlogy4Regular(size: 14))
                    .foregroundStyle(Color(hex: "#FF676F"))
                    .padding(.horizontal, AppSpacing.m)
                    .frame(height: 38)
                    .overlay {
                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                            .stroke(Color(hex: "#FF676F"), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.s)
        .background(
            Color.white.opacity(0.1),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        }
    }

    private func unblockConfirmationSheet(user: UserModel, safeAreaBottomInset: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.62)
                .ignoresSafeArea()
                .onTapGesture {
                    guard !viewModel.isUnblockingUser else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        pendingUnblockUser = nil
                    }
                }

            VStack(spacing: AppSpacing.s) {
                Text("!")
                    .font(.system(size: 36, weight: .heavy))
                    .foregroundStyle(Color(hex: "#FF676F"))

                Text("\(user.displayName)님을 차단 해제 할까요?")
                    .font(AppFont.paperlogy6SemiBold(size: 31))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("이제 상대방이 검색할 수 있습니다.\n상대방에게 알림이 가지 않습니다.")
                    .font(AppFont.paperlogy5Medium(size: 16))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)

                if let unblockErrorMessage = viewModel.unblockErrorMessage {
                    Text(unblockErrorMessage)
                        .font(AppFont.paperlogy4Regular(size: 12))
                        .foregroundStyle(Color(hex: "#FF676F"))
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: AppSpacing.s) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            pendingUnblockUser = nil
                        }
                    } label: {
                        Text("취소")
                            .font(AppFont.paperlogy6SemiBold(size: 20))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isUnblockingUser)

                    Button {
                        Task {
                            let isSuccess = await viewModel.unblockUser(blockedId: user.userId)
                            if isSuccess {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    pendingUnblockUser = nil
                                }
                            }
                        }
                    } label: {
                        Group {
                            if viewModel.isUnblockingUser {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("삭제")
                                    .font(AppFont.paperlogy6SemiBold(size: 20))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(hex: "#FF676F"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isUnblockingUser)
                }
                .padding(.top, AppSpacing.s)
            }
            .padding(.horizontal, AppSpacing.l)
            .padding(.top, AppSpacing.l)
            .padding(.bottom, max(safeAreaBottomInset, AppSpacing.m))
            .background(Color(hex: "#242527"))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
            .padding(.horizontal, AppSpacing.s)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .animation(.easeInOut(duration: 0.2), value: pendingUnblockUser != nil)
    }
}
