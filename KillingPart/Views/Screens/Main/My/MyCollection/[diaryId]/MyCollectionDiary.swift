import SwiftUI

struct MyCollectionDiary: View {
    let diaryId: Int
    let diary: DiaryFeedModel

    @State private var displayedStart: String
    @State private var displayedEnd: String
    @State private var displayedContent: String
    @State private var isDeleteDialogPresented = false
    @State private var isDeleted = false
    @State private var isEditSheetPresented = false
    @State private var editStartDraft: String
    @State private var editEndDraft: String
    @State private var editContentDraft: String

    private let videoAspectRatio: CGFloat = 16 / 9
    private let videoCornerRadius: CGFloat = 16

    init(diaryId: Int, diary: DiaryFeedModel) {
        self.diaryId = diaryId
        self.diary = diary
        _displayedStart = State(initialValue: diary.start)
        _displayedEnd = State(initialValue: diary.end)
        _displayedContent = State(initialValue: diary.content)
        _editStartDraft = State(initialValue: diary.start)
        _editEndDraft = State(initialValue: diary.end)
        _editContentDraft = State(initialValue: diary.content)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isDeleted {
                deletedPlaceholder
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.m) {
                        videoSection
                        trackSection
                        commentSection
                        bottomMetaSection
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.m)
                    .padding(.bottom, AppSpacing.l)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    isDeleteDialogPresented = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.white)
                }

                Button {
                    beginEdit()
                    isEditSheetPresented = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(.white)
                }
            }
        }
        .confirmationDialog(
            "일기를 삭제할까요?",
            isPresented: $isDeleteDialogPresented,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                isDeleted = true
            }
            Button("취소", role: .cancel) { }
        }
        .sheet(isPresented: $isEditSheetPresented) {
            editSheet
        }
    }

    private var videoSection: some View {
        YoutubePlayerView(
            videoURL: videoURL,
            startSeconds: startSeconds,
            endSeconds: endSeconds
        )
        .frame(maxWidth: .infinity)
        .aspectRatio(videoAspectRatio, contentMode: .fit)
        .allowsHitTesting(false)
        .clipShape(RoundedRectangle(cornerRadius: videoCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: videoCornerRadius)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var trackSection: some View {
        HStack(spacing: AppSpacing.m) {
            AddSearchDetailAlbumArtworkView(url: diary.albumImageURL)
                .zIndex(2)

            VStack(alignment: .leading, spacing: 6) {
                Text(diary.musicTitle)
                    .font(AppFont.paperlogy6SemiBold(size: 16))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(diary.artist)
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)

                timelineRangeSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.m)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.15),
                    Color.white.opacity(0.02)
                ],
                startPoint: .trailing,
                endPoint: .leading
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var timelineRangeSection: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let startX = width * startProgress
            let endX = width * endProgress
            let segmentWidth = max(endX - startX, 2)
            let horizontalPadding: CGFloat = 22
            let labelPositions = adjustedLabelPositions(
                startX: startX,
                endX: endX,
                width: width,
                horizontalPadding: horizontalPadding,
                minLabelGap: 34
            )

            let labelY: CGFloat = 24

            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: width, height: 3)
                    .offset(y: 5)

                Capsule()
                    .fill(AppColors.primary600.opacity(0.95))
                    .frame(width: segmentWidth, height: 7)
                    .offset(x: startX, y: 3)

                Text(startMinuteSecondText)
                    .font(AppFont.paperlogy6SemiBold(size: 10))
                    .foregroundStyle(AppColors.primary600.opacity(0.98))
                    .position(x: labelPositions.start, y: labelY)

                Text(endMinuteSecondText)
                    .font(AppFont.paperlogy5Medium(size: 10))
                    .foregroundStyle(AppColors.primary600.opacity(0.9))
                    .position(x: labelPositions.end, y: labelY)
            }
        }
        .frame(height: 40)
    }

    private var commentSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("코멘트")
                .font(AppFont.paperlogy5Medium(size: 14))
                .foregroundStyle(.white.opacity(0.82))

            Text(displayedContent.isEmpty ? "작성된 코멘트가 없어요." : displayedContent)
                .font(AppFont.paperlogy4Regular(size: 14))
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.leading)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.s)
                .padding(.vertical, 14)
                .frame(minHeight: 190, alignment: .topLeading)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
        }
    }

    private var bottomMetaSection: some View {
        HStack(alignment: .bottom) {
            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                Text(createdDateText)
                    .font(AppFont.paperlogy4Regular(size: 12))
                    .foregroundStyle(.white.opacity(0.62))

                Text(tagText)
                    .font(AppFont.paperlogy5Medium(size: 13))
                    .foregroundStyle(.white.opacity(0.86))
            }
        }
    }

    private var deletedPlaceholder: some View {
        VStack(spacing: AppSpacing.s) {
            Image(systemName: "trash")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            Text("삭제 처리 UI가 적용되었어요.")
                .font(AppFont.paperlogy5Medium(size: 14))
                .foregroundStyle(.white.opacity(0.85))
            Text("API 연동 전 단계라 서버 반영은 하지 않아요.")
                .font(AppFont.paperlogy4Regular(size: 12))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, AppSpacing.l)
    }

    private var editSheet: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.m) {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("시작 초")
                                .font(AppFont.paperlogy5Medium(size: 13))
                                .foregroundStyle(.white.opacity(0.8))
                            TextField("", text: $editStartDraft)
                                .font(AppFont.paperlogy4Regular(size: 14))
                                .foregroundStyle(.white)
                                .padding(.horizontal, AppSpacing.s)
                                .padding(.vertical, AppSpacing.s)
                                .background(Color.white.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("종료 초")
                                .font(AppFont.paperlogy5Medium(size: 13))
                                .foregroundStyle(.white.opacity(0.8))
                            TextField("", text: $editEndDraft)
                                .font(AppFont.paperlogy4Regular(size: 14))
                                .foregroundStyle(.white)
                                .padding(.horizontal, AppSpacing.s)
                                .padding(.vertical, AppSpacing.s)
                                .background(Color.white.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("코멘트")
                                .font(AppFont.paperlogy5Medium(size: 13))
                                .foregroundStyle(.white.opacity(0.8))
                            TextEditor(text: $editContentDraft)
                                .font(AppFont.paperlogy4Regular(size: 14))
                                .foregroundColor(.white)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 180)
                                .padding(AppSpacing.xs)
                                .background(Color.white.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(AppSpacing.l)
                }
            }
            .navigationTitle("일기 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        isEditSheetPresented = false
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        applyEdit()
                        isEditSheetPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    private var videoURL: URL? {
        let trimmed = diary.videoUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let parsed = URL(string: trimmed), parsed.scheme != nil {
            return parsed
        }
        if trimmed.hasPrefix("//"), let parsed = URL(string: "https:\(trimmed)") {
            return parsed
        }
        return URL(string: "https://\(trimmed)")
    }

    private var startSeconds: Double {
        parsedSeconds(from: displayedStart) ?? 0
    }

    private var endSeconds: Double {
        let parsedEnd = parsedSeconds(from: displayedEnd) ?? startSeconds
        return max(parsedEnd, startSeconds + 0.1)
    }

    private var totalSeconds: Double {
        let parsedTotal = parsedSeconds(from: diary.totalDuration) ?? 0
        return max(parsedTotal, endSeconds, 1)
    }

    private var startProgress: CGFloat {
        CGFloat(min(max(startSeconds / totalSeconds, 0), 1))
    }

    private var endProgress: CGFloat {
        CGFloat(min(max(endSeconds / totalSeconds, startSeconds / totalSeconds), 1))
    }

    private var startMinuteSecondText: String {
        TimeFormatter.minuteSecondText(from: startSeconds)
    }

    private var endMinuteSecondText: String {
        TimeFormatter.minuteSecondText(from: endSeconds)
    }

    private var createdDateText: String {
        let raw = diary.createDate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "-" }
        let datePart = raw.split(separator: "T").first.map(String.init) ?? raw
        return datePart.replacingOccurrences(of: "-", with: ".")
    }

    private var tagText: String {
        let raw = (diary.tag ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "@killingpart_user" }
        return raw.hasPrefix("@") ? raw : "@\(raw)"
    }

    private func beginEdit() {
        editStartDraft = displayedStart
        editEndDraft = displayedEnd
        editContentDraft = displayedContent
    }

    private func applyEdit() {
        displayedStart = editStartDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        displayedEnd = editEndDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        displayedContent = editContentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parsedSeconds(from value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let raw = Double(trimmed) {
            return max(raw, 0)
        }

        let sanitized = trimmed.replacingOccurrences(of: "초", with: "")
        if sanitized.contains(":") {
            let parts = sanitized.split(separator: ":").map(String.init)
            guard parts.count == 2,
                  let minutes = Double(parts[0]),
                  let seconds = Double(parts[1]) else {
                return nil
            }
            return max((minutes * 60) + seconds, 0)
        }

        if let raw = Double(sanitized) {
            return max(raw, 0)
        }

        return nil
    }

    private func adjustedLabelPositions(
        startX: CGFloat,
        endX: CGFloat,
        width: CGFloat,
        horizontalPadding: CGFloat,
        minLabelGap: CGFloat
    ) -> (start: CGFloat, end: CGFloat) {
        let clampedStart = min(max(startX, horizontalPadding), width - horizontalPadding)
        let clampedEnd = min(max(endX, horizontalPadding), width - horizontalPadding)

        var adjustedStart = clampedStart
        var adjustedEnd = clampedEnd
        let currentGap = adjustedEnd - adjustedStart

        if currentGap < minLabelGap {
            let neededGap = minLabelGap - currentGap
            adjustedStart -= neededGap / 2
            adjustedEnd += neededGap / 2

            if adjustedStart < horizontalPadding {
                let delta = horizontalPadding - adjustedStart
                adjustedStart += delta
                adjustedEnd += delta
            }

            let maxX = width - horizontalPadding
            if adjustedEnd > maxX {
                let delta = adjustedEnd - maxX
                adjustedStart -= delta
                adjustedEnd -= delta
            }

            adjustedStart = min(max(adjustedStart, horizontalPadding), width - horizontalPadding)
            adjustedEnd = min(max(adjustedEnd, horizontalPadding), width - horizontalPadding)
        }

        return (adjustedStart, adjustedEnd)
    }

}
