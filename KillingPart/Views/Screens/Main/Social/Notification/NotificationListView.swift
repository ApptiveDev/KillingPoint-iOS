import SwiftUI

struct NotificationListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SocialViewModel

    @State private var selectedAlarmForDetail: AlarmHistoryItem?
    @State private var isDetailCardFloating = false

    var body: some View {
        GeometryReader { geometry in
            let bottomInset = max(geometry.safeAreaInsets.bottom, AppSpacing.m)

            ZStack {
                Image("my_background")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, AppSpacing.m)
                        .padding(.top, AppSpacing.s)
                        .padding(.bottom, AppSpacing.s)

                    if viewModel.isAlarmSelectionMode {
                        selectionToolbar
                            .padding(.horizontal, AppSpacing.m)
                            .padding(.bottom, AppSpacing.s)
                    }

                    content
                        .padding(.horizontal, AppSpacing.m)
                }
                .padding(.bottom, bottomInset)

                if let selectedAlarmForDetail {
                    alarmDetailOverlay(for: selectedAlarmForDetail)
                        .transition(.opacity)
                        .zIndex(10)
                }
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
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.kpPrimary)
                Text("알림 목록")
                    .font(AppFont.paperlogy7Bold(size: 20))
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
    private var content: some View {
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
                .padding(.bottom, AppSpacing.xl)
            }
        }
    }

    private func alarmRow(for alarm: AlarmHistoryItem) -> some View {
        let isRead = viewModel.isAlarmRead(alarm.alarmId)
        let isSelected = viewModel.selectedAlarmIDs.contains(alarm.alarmId)
        let rowOpacity = isRead ? 0.36 : 1

        return Button {
            if viewModel.isAlarmSelectionMode {
                viewModel.toggleAlarmSelection(alarm.alarmId)
                return
            }

            viewModel.markAlarmAsRead(alarm.alarmId)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                selectedAlarmForDetail = alarm
            }
            startFloatingAnimation()
        } label: {
            HStack(spacing: AppSpacing.s) {
                if viewModel.isAlarmSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isSelected ? Color.kpPrimary : Color.white.opacity(0.45))
                }

                Text(alarm.displayContent)
                    .font(AppFont.paperlogy4Regular(size: 15))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(alarm.displayDate)
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(Color.white.opacity(0.74))
                    .frame(minWidth: 48, alignment: .trailing)
            }
            .padding(.vertical, AppSpacing.m)
            .padding(.horizontal, AppSpacing.xs)
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
        .buttonStyle(.plain)
    }

    private func alarmDetailOverlay(for alarm: AlarmHistoryItem) -> some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    closeDetailCard()
                }

            VStack(spacing: AppSpacing.s) {
                HStack {
                    Text(alarm.displayTitle)
                        .font(AppFont.paperlogy6SemiBold(size: 18))
                        .foregroundStyle(Color.kpPrimary)
                    Spacer()
                }

                HStack {
                    Text(alarm.displayDetailDate)
                        .font(AppFont.paperlogy4Regular(size: 12))
                        .foregroundStyle(Color.white.opacity(0.62))
                    Spacer()
                }

                Text(alarm.displayContent)
                    .font(AppFont.paperlogy5Medium(size: 15))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, AppSpacing.xs)

                if !alarm.displayDeepLink.isEmpty {
                    Text("연결: \(alarm.displayDeepLink)")
                        .font(AppFont.paperlogy4Regular(size: 12))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, AppSpacing.xs)
                }

                Button {
                    closeDetailCard()
                } label: {
                    Text("닫기")
                        .font(AppFont.paperlogy5Medium(size: 14))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.kpPrimary)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, AppSpacing.s)
            }
            .padding(AppSpacing.m)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.94))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.38), radius: 16, y: 10)
            .padding(.horizontal, AppSpacing.l)
            .offset(y: isDetailCardFloating ? -8 : 8)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isDetailCardFloating)
            .onAppear {
                startFloatingAnimation()
            }
        }
    }

    private func closeDetailCard() {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedAlarmForDetail = nil
        }
        isDetailCardFloating = false
    }

    private func startFloatingAnimation() {
        isDetailCardFloating = false
        DispatchQueue.main.async {
            isDetailCardFloating = true
        }
    }
}

private extension AlarmHistoryItem {
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "알림" : trimmed
    }

    var displayContent: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "내용이 없는 알림입니다." : trimmed
    }

    var displayDeepLink: String {
        deepLink.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayDate: String {
        AlarmDateFormatter.shortDate(from: createDate ?? "")
    }

    var displayDetailDate: String {
        AlarmDateFormatter.detailDate(from: createDate ?? "")
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
        formatter.dateFormat = "MM.dd"
        return formatter
    }()

    private static let detailOutput: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter
    }()

    static func shortDate(from rawDate: String) -> String {
        guard let date = parse(rawDate) else { return "--.--" }
        return shortOutput.string(from: date)
    }

    static func detailDate(from rawDate: String) -> String {
        guard let date = parse(rawDate) else { return "날짜 정보 없음" }
        return detailOutput.string(from: date)
    }

    private static func parse(_ rawDate: String) -> Date? {
        let trimmed = rawDate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let date = inputWithFractionalSeconds.date(from: trimmed) {
            return date
        }

        return inputWithoutFractionalSeconds.date(from: trimmed)
    }
}

#Preview {
    NavigationStack {
        NotificationListView(viewModel: SocialViewModel())
    }
}
