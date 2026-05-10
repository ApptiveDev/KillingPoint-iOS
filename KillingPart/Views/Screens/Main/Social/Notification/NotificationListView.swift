import SwiftUI

struct NotificationListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SocialViewModel

    var body: some View {
        GeometryReader { geometry in
            let bottomInset = max(geometry.safeAreaInsets.bottom, AppSpacing.m)
            let listBottomInset = bottomInset + 56

            ZStack {
                Image("my_background")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

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
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadAlarmHistoryIfNeeded()
        }
        .refreshable {
            await viewModel.refreshAlarms()
        }
        .onDisappear {
            viewModel.setAlarmSelectionMode(false)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isAlarmSelectionMode)
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
                Text(viewModel.selectedAlarmIDs.count == viewModel.alarms.count ? "전체 해제" : "전체 선택")
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
                viewModel.markSelectedAlarmsAsRead()
            } label: {
                Text("선택 읽기")
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
            .disabled(viewModel.selectedAlarmIDs.isEmpty)

            Button {
                viewModel.markAllAlarmsAsRead()
            } label: {
                Text("모두 읽기")
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
                    ForEach(viewModel.alarms) { alarm in
                        alarmRow(for: alarm)
                            .onAppear {
                                Task {
                                    await viewModel.loadMoreAlarmHistoryIfNeeded(currentAlarmId: alarm.alarmId)
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
    private func alarmRow(for alarm: AlarmHistoryItem) -> some View {
        let isSelected = viewModel.selectedAlarmIDs.contains(alarm.alarmId)

        if viewModel.isAlarmSelectionMode {
            Button {
                viewModel.toggleAlarmSelection(alarm.alarmId)
            } label: {
                alarmRowContent(for: alarm, isSelected: isSelected)
            }
            .buttonStyle(.plain)
        } else {
            alarmRowContent(for: alarm, isSelected: false)
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

#Preview {
    NavigationStack {
        NotificationListView(viewModel: SocialViewModel())
    }
}
