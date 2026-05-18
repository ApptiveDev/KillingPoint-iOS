import SwiftUI

struct SocialDiaryLikeUsersSheet: View {
    let title: String
    @Binding var searchText: String
    let users: [UserModel]
    let isLoading: Bool
    let isLoadingMore: Bool
    let errorMessage: String?
    let emptyMessage: String
    let onSearchSubmit: () -> Void
    let onSearchClear: () -> Void
    let onRetry: () -> Void
    let onUserAppear: (Int) -> Void
    let onUserTap: (UserModel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text(title)
                .font(AppFont.paperlogy6SemiBold(size: 16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            searchBar

            if isLoading && users.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(AppColors.primary600)
                    Spacer()
                }
                .padding(.top, AppSpacing.xl)
            } else if let errorMessage, users.isEmpty {
                VStack(spacing: AppSpacing.s) {
                    Text(errorMessage)
                        .font(AppFont.paperlogy4Regular(size: 13))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .multilineTextAlignment(.center)

                    Button("다시 시도") {
                        onRetry()
                    }
                    .font(AppFont.paperlogy5Medium(size: 13))
                    .foregroundStyle(AppColors.primary600)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, AppSpacing.xl)
            } else if users.isEmpty {
                Text(emptyMessage)
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, AppSpacing.xl)
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.s) {
                        ForEach(users) { user in
                            Button {
                                onUserTap(user)
                            } label: {
                                SocialFriendRowView(user: .searched(user))
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                onUserAppear(user.userId)
                            }
                        }

                        if isLoadingMore {
                            ProgressView()
                                .tint(AppColors.primary600)
                                .padding(.top, AppSpacing.s)
                        }
                    }
                    .padding(.bottom, AppSpacing.m)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.top, AppSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    private var searchBar: some View {
        HStack(spacing: AppSpacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.white.opacity(0.75))

            TextField("태그 또는 유저 검색", text: $searchText)
                .font(AppFont.paperlogy4Regular(size: 14))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    onSearchSubmit()
                }

            Button {
                onSearchSubmit()
            } label: {
                Text("검색")
                    .font(AppFont.paperlogy5Medium(size: 12))
                    .foregroundStyle(AppColors.primary600)
            }
            .buttonStyle(.plain)

            if !searchText.isEmpty {
                Button {
                    onSearchClear()
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
}
