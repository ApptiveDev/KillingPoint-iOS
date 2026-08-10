import SwiftUI

struct NotificationListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: NotificationListViewModel

    var body: some View {
        GeometryReader { geometry in
            let bottomInset = max(geometry.safeAreaInsets.bottom, AppSpacing.m)
            let listBottomInset = bottomInset + 56

            ZStack {
                KillingPartBackgroundView()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, AppSpacing.m)
                        .padding(.top, 0)
                        .padding(.bottom, AppSpacing.s)

                    if viewModel.isAlarmSelectionMode {
                        selectionToolbar
                            .padding(.horizontal, AppSpacing.m)
                            .padding(.bottom, AppSpacing.s)
                    }

                    content(listBottomInset: listBottomInset)
                        .padding(.horizontal, AppSpacing.m)
                }
                .padding(.bottom, bottomInset)
                .background(alarmNavigationLinks)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.enterList()
        }
        .refreshable {
            await viewModel.refreshAlarms()
        }
        .onDisappear {
            viewModel.exitList()
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isAlarmSelectionMode)
        .alert(
            "알림 이동 실패",
            isPresented: routingErrorPresentedBinding
        ) {
            Button("확인", role: .cancel) {
                viewModel.clearRoutingError()
            }
        } message: {
            Text(viewModel.routingErrorMessage ?? "알림을 열 수 없어요.")
        }
        .sheet(isPresented: subscribeFansSheetPresentedBinding) {
            NotificationSubscribeFansSheet(
                users: viewModel.subscribeFans,
                isLoading: viewModel.isLoadingSubscribeFans,
                isLoadingMore: viewModel.isLoadingMoreSubscribeFans,
                errorMessage: viewModel.subscribeFansErrorMessage,
                onRetry: {
                    Task {
                        await viewModel.refreshSubscribeFans()
                    }
                },
                onUserAppear: { userId in
                    Task {
                        await viewModel.loadMoreSubscribeFansIfNeeded(currentUserId: userId)
                    }
                },
                onUserTap: { user in
                    viewModel.routeToSubscribeFan(user)
                }
            )
        }
    }

    private var header: some View {
        HStack(spacing: AppSpacing.s) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "bell")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.kpPrimary)

                Text("알림 목록")
                    .font(AppFont.paperlogy6SemiBold(size: 18))
                    .foregroundStyle(Color.kpPrimary)
            }

            Spacer()

            Button {
                viewModel.setAlarmSelectionMode(!viewModel.isAlarmSelectionMode)
            } label: {
                Text(viewModel.isAlarmSelectionMode ? "취소" : "선택")
                    .font(AppFont.paperlogy5Medium(size: 14))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
        }
    }

    private var selectionToolbar: some View {
        HStack(spacing: AppSpacing.s) {
            Button {
                viewModel.toggleSelectAllAlarms()
            } label: {
                Text(
                    !viewModel.alarms.isEmpty && viewModel.selectedAlarmIDs.count == viewModel.alarms.count
                        ? "전체 해제"
                        : "전체 선택"
                )
                    .font(AppFont.paperlogy5Medium(size: 12))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, AppSpacing.s)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                viewModel.deleteSelectedAlarms()
            } label: {
                Text(viewModel.isDeletingAlarms ? "삭제 중" : "선택 삭제")
                    .font(AppFont.paperlogy5Medium(size: 12))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, AppSpacing.s)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.kpPrimary.opacity(viewModel.selectedAlarmIDs.isEmpty ? 0.35 : 1))
                    )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.selectedAlarmIDs.isEmpty || viewModel.isDeletingAlarms)

            Button {
                viewModel.deleteAllAlarms()
            } label: {
                Text("모두 삭제")
                    .font(AppFont.paperlogy5Medium(size: 12))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, AppSpacing.s)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.alarms.isEmpty || viewModel.isDeletingAlarms)
        }
    }

    @ViewBuilder
    private func content(listBottomInset: CGFloat) -> some View {
        if viewModel.isLoadingAlarms {
            ProgressView()
                .tint(AppColors.primary600)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, AppSpacing.xl)
        } else if let alarmsErrorMessage = viewModel.alarmsErrorMessage, viewModel.alarms.isEmpty {
            VStack(spacing: AppSpacing.s) {
                Text(alarmsErrorMessage)
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .multilineTextAlignment(.center)

                Button("다시 시도") {
                    Task {
                        await viewModel.refreshAlarms()
                    }
                }
                .font(AppFont.paperlogy5Medium(size: 13))
                .foregroundStyle(AppColors.primary600)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, AppSpacing.xl)
        } else if viewModel.alarms.isEmpty {
            Text("알림이 아직 없어요.")
                .font(AppFont.paperlogy4Regular(size: 14))
                .foregroundStyle(Color.white.opacity(0.72))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, AppSpacing.xl)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.alarms.enumerated()), id: \.element.id) { indexedAlarm in
                        alarmRow(
                            for: indexedAlarm.element,
                            listPosition: indexedAlarm.offset
                        )
                            .onAppear {
                                Task {
                                    await viewModel.loadMoreAlarmHistoryIfNeeded(
                                        currentAlarmId: indexedAlarm.element.alarmId
                                    )
                                }
                            }
                    }

                    if viewModel.isLoadingMoreAlarms {
                        ProgressView()
                            .tint(AppColors.primary600)
                            .padding(.vertical, AppSpacing.s)
                    }
                }
                .padding(.bottom, listBottomInset)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private func alarmRow(for alarm: AlarmHistoryItem, listPosition: Int) -> some View {
        let isSelected = viewModel.selectedAlarmIDs.contains(alarm.alarmId)

        if viewModel.isAlarmSelectionMode {
            Button {
                print("[NotificationRoute] selection tap alarmId=\(alarm.alarmId)")
                viewModel.toggleAlarmSelection(alarm.alarmId)
            } label: {
                alarmRowContent(for: alarm, isSelected: isSelected)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                print(
                    "[NotificationRoute] row tap alarmId=\(alarm.alarmId) type=\(alarm.type.rawValue) deepLink=\(alarm.deepLink)"
                )
                Task {
                    await viewModel.handleAlarmTap(alarm, listPosition: listPosition)
                }
            } label: {
                alarmRowContent(for: alarm, isSelected: false)
            }
            .buttonStyle(.plain)
        }
    }

    private func alarmRowContent(for alarm: AlarmHistoryItem, isSelected: Bool) -> some View {
        let isRead = viewModel.isAlarmRead(alarm.alarmId)
        let rowOpacity = isRead ? 0.36 : 1
        let rowSpacing = viewModel.isAlarmSelectionMode ? 6.0 : 10.0
        let horizontalPadding: CGFloat = viewModel.isAlarmSelectionMode ? 0 : AppSpacing.xs

        return HStack(spacing: rowSpacing) {
            if viewModel.isAlarmSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSelected ? Color.kpPrimary : Color.white.opacity(0.45))
                    .frame(width: 18)
            }

            Text(alarm.displayContent)
                .font(AppFont.paperlogy4Regular(size: 15))
                .foregroundStyle(Color.white.opacity(0.92))
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .truncationMode(.tail)
                .layoutPriority(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(alarm.displayDate)
                .font(AppFont.paperlogy4Regular(size: 13))
                .foregroundStyle(Color.white.opacity(0.74))
                .lineLimit(1)
                .frame(minWidth: 40, alignment: .trailing)
        }
        .padding(.vertical, AppSpacing.m)
        .padding(.horizontal, horizontalPadding)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.kpPrimary.opacity(0.12) : .clear)
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
        .opacity(rowOpacity)
    }

    private var alarmNavigationLinks: some View {
        ZStack {
            NavigationLink(
                isActive: myDiaryNavigationBinding,
                destination: {
                    if let destination = viewModel.activeMyDiaryDestination {
                        MyCollectionDiary(
                            diaryId: destination.diary.diaryId,
                            displayTag: destination.displayTag,
                            diary: destination.diary,
                            analyticsEntryPoint: destination.analyticsEntryPoint
                        )
                    } else {
                        EmptyView()
                    }
                },
                label: {
                    EmptyView()
                }
            )
            .hidden()

            NavigationLink(
                isActive: socialDiaryNavigationBinding,
                destination: {
                    if let destination = viewModel.activeSocialDiaryDestination {
                        SocialMyCollectionDiary(
                            diaryId: destination.diary.diaryId,
                            displayTag: destination.displayTag,
                            diary: destination.diary,
                            analyticsEntryPoint: destination.analyticsEntryPoint,
                            makeCollectionViewModel: { user in
                                viewModel.makeSocialMyCollectionViewModel(for: user)
                            }
                        )
                    } else {
                        EmptyView()
                    }
                },
                label: {
                    EmptyView()
                }
            )
            .hidden()

            NavigationLink(
                isActive: socialCollectionNavigationBinding,
                destination: {
                    if let destination = viewModel.activeSocialCollectionDestination {
                        SocialMyCollectionView(
                            viewModel: viewModel.makeSocialMyCollectionViewModel(
                                for: destination.user,
                                initialUserFeedsResponse: destination.initialUserFeedsResponse
                            ),
                            analyticsEntryPoint: destination.analyticsEntryPoint
                        )
                        .id(destination.user.userId)
                    } else {
                        EmptyView()
                    }
                },
                label: {
                    EmptyView()
                }
            )
            .hidden()
        }
    }

    private var myDiaryNavigationBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.activeMyDiaryDestination != nil
            },
            set: { isActive in
                guard !isActive else { return }
                viewModel.clearActiveMyDiaryDestination()
            }
        )
    }

    private var socialDiaryNavigationBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.activeSocialDiaryDestination != nil
            },
            set: { isActive in
                guard !isActive else { return }
                viewModel.clearActiveSocialDiaryDestination()
            }
        )
    }

    private var socialCollectionNavigationBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.activeSocialCollectionDestination != nil
            },
            set: { isActive in
                guard !isActive else { return }
                viewModel.clearActiveSocialCollectionDestination()
            }
        )
    }

    private var routingErrorPresentedBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.routingErrorMessage != nil
            },
            set: { isPresented in
                guard !isPresented else { return }
                viewModel.clearRoutingError()
            }
        )
    }

    private var subscribeFansSheetPresentedBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.isSubscribeFansSheetPresented
            },
            set: { isPresented in
                guard !isPresented else { return }
                viewModel.dismissSubscribeFansSheet()
            }
        )
    }
}

private extension AlarmHistoryItem {
    var displayContent: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "내용이 없는 알림입니다." : trimmed
    }

    var displayDate: String {
        AlarmDateFormatter.shortDate(from: createDate ?? "")
    }
}

private enum AlarmDateFormatter {
    private static let inputWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let inputWithoutFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let shortOutput: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yy.MM"
        return formatter
    }()

    static func shortDate(from rawDate: String) -> String {
        guard let date = parse(rawDate) else { return shortOutput.string(from: Date()) }
        return shortOutput.string(from: date)
    }

    private static func parse(_ rawDate: String) -> Date? {
        let trimmed = rawDate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let date = inputWithFractionalSeconds.date(from: trimmed) {
            return date
        }

        if let date = inputWithoutFractionalSeconds.date(from: trimmed) {
            return date
        }

        for format in serverDateFormats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        return nil
    }

    private static let serverDateFormats: [String] = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd HH:mm:ss"
    ]
}

private struct NotificationSubscribeFansSheet: View {
    let users: [SubscribeUserModel]
    let isLoading: Bool
    let isLoadingMore: Bool
    let errorMessage: String?
    let onRetry: () -> Void
    let onUserAppear: (Int) -> Void
    let onUserTap: (SubscribeUserModel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("내 팬덤")
                .font(AppFont.paperlogy6SemiBold(size: 16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

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
                Text("표시할 친구가 없어요.")
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
                                SocialFriendRowView(user: .subscribed(user))
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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    NavigationStack {
        NotificationListView(viewModel: NotificationListViewModel())
    }
}
