import SwiftUI
import UIKit

enum AddSearchDetailTrimInteractionControl: String {
    case left
    case right
    case spectrumBar = "spectrum_bar"
    case minusOneSecond = "minus_1s"
    case plusOneSecond = "plus_1s"
}

struct AddSearchDetailWaveformTrimView: View {
    @Binding var startSeconds: Double
    @Binding var endSeconds: Double
    let duration: Double
    let playbackSeconds: Double
    let startTimeText: String
    let endTimeText: String
    let onTrimInteracted: () -> Void
    let onInteractionEnded: (_ control: AddSearchDetailTrimInteractionControl) -> Void
    let onUpdateRange: (_ start: Double, _ end: Double) -> Void
    let onSeekRequested: (_ seconds: Double) -> Void
    let onHandleLoopActivated: (_ control: AddSearchDetailTrimInteractionControl) -> Void
    let onHandleLoopDeactivated: () -> Void
    let onHandleDragMovementChanged: (_ isDragging: Bool) -> Void

    private let horizontalPadding: CGFloat = 18
    private let pointsPerSecond: CGFloat = 8
    private let trackHeight: CGFloat = 84
    private let handleLabelHeight: CGFloat = 18
    private let handleLabelWidth: CGFloat = 76
    private let overviewHeight: CGFloat = 24
    private let overviewHorizontalInset: CGFloat = 8
    private let barWidth: CGFloat = 4
    private let barSpacing: CGFloat = 3
    private let handleWidth: CGFloat = 20
    private let handleCornerRadius: CGFloat = 14
    private let handleBodyCornerRadius: CGFloat = 7
    private let handleVerticalInset: CGFloat = 8
    private let handleEdgeInset: CGFloat = 3
    private let autoScrollEdgeThreshold: CGFloat = 52
    private let autoScrollMaxVelocity: CGFloat = 260
    private let followButtonSize: CGFloat = 30
    private let followButtonInset: CGFloat = 10
    private let nudgeButtonSize: CGFloat = 30
    private let playheadWidth: CGFloat = 3
    private let handleTapMaxTranslation: CGFloat = 4
    private let selectionBorderLineWidth: CGFloat = 1.5
    private let maximumClipDuration: Double = 30
    private let handlePressedScale: CGFloat = 1.12
    private let selectionRecenterDelay: TimeInterval = 0.4
    private let handleLoopActivationDelay: TimeInterval = 0.5
    private let boundaryLoopDuration: Double = 2
    private let nudgeAnimation = Animation.spring(response: 0.3, dampingFraction: 0.85)
    private let offscreenFollowThreshold: CGFloat = 6
    private let timelineCoordinateSpaceName = "addSearchDetailTimeline"

    @State private var startDragBase: Double?
    @State private var endDragBase: Double?
    @State private var activeHandleDragDirection: HandleDirection?
    @State private var activeHandleDragTranslation: CGFloat = 0
    @State private var activeHandleContentWidth: CGFloat = 1
    @State private var autoScrollAdditionalSeconds: Double = 0
    @State private var autoScrollVelocity: CGFloat = 0
    @State private var autoScrollTimer: Timer?
    @State private var autoScrollLastTick: CFTimeInterval?
    @State private var timelineScrollView: UIScrollView?
    @State private var timelineViewportOffsetX: CGFloat = 0
    @State private var timelineViewportWidth: CGFloat = 0
    @State private var timelineContentWidth: CGFloat = 0
    @State private var timelineScrollEndWorkItem: DispatchWorkItem?
    @State private var selectionRecenterWorkItem: DispatchWorkItem?
    @State private var handleLoopWorkItem: DispatchWorkItem?
    @State private var activeLoopDirection: HandleDirection?

    var body: some View {
        GeometryReader { proxy in
            let viewportWidth = max(proxy.size.width, 1)
            let contentWidth = max(
                viewportWidth,
                CGFloat(max(duration, 1)) * pointsPerSecond + horizontalPadding * 2
            )

            VStack(spacing: AppSpacing.xs) {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: AppSpacing.xs) {
                        trimTrack(contentWidth: contentWidth, viewportWidth: viewportWidth)
                            .frame(width: contentWidth, height: trackHeight)

                        handleTimeLabels(contentWidth: contentWidth)
                            .frame(width: contentWidth, height: handleLabelHeight)
                    }
                    .background {
                        AddSearchDetailScrollViewResolver(
                            onResolve: { scrollView in
                                if timelineScrollView !== scrollView {
                                    timelineScrollView = scrollView
                                }
                            },
                            onViewportChange: { viewport in
                                handleTimelineViewportChanged(viewport)
                            }
                        )
                    }
                }
                .coordinateSpace(name: timelineCoordinateSpaceName)
                .onAppear {
                    if let scrollView = timelineScrollView {
                        timelineViewportOffsetX = scrollView.contentOffset.x
                        timelineViewportWidth = scrollView.bounds.width
                        timelineContentWidth = scrollView.contentSize.width
                    }
                }
                HStack {
                    secondNudgeButton(title: "-1s") {
                        nudgeSelection(by: -1)
                    }

                    Spacer()

                    secondNudgeButton(title: "+1s") {
                        nudgeSelection(by: 1)
                    }
                }

                overviewBar(width: viewportWidth)
            }
        }
        .onDisappear {
            stopAutoScrollTimer()
            timelineScrollEndWorkItem?.cancel()
            timelineScrollEndWorkItem = nil
            selectionRecenterWorkItem?.cancel()
            selectionRecenterWorkItem = nil
            cancelHandleLoop()
            onHandleDragMovementChanged(false)
        }
    }

    private func trimTrack(contentWidth: CGFloat, viewportWidth: CGFloat) -> some View {
        let startX = xPosition(for: startSeconds, contentWidth: contentWidth)
        let endX = xPosition(for: endSeconds, contentWidth: contentWidth)
        let selectedWidth = max(endX - startX, 1)
        let trailingWidth = max(contentWidth - endX, 0)
        let loopBandRange = loopBandXRange(startX: startX, endX: endX, contentWidth: contentWidth)
        let playheadX = playheadXPosition(
            startX: startX,
            endX: endX,
            contentWidth: contentWidth,
            loopBandRange: loopBandRange
        )
        let visibleRange = timelineVisibleRange(
            contentWidth: contentWidth,
            fallbackViewportWidth: viewportWidth
        )
        let isStartOffscreen = startX < visibleRange.lowerBound - offscreenFollowThreshold
        let isEndOffscreen = endX > visibleRange.upperBound + offscreenFollowThreshold

        return ZStack(alignment: .leading) {
            if let loopBandRange {
                RoundedRectangle(cornerRadius: 5)
                    .fill(AppColors.primary600.opacity(0.28))
                    .frame(
                        width: loopBandRange.upperBound - loopBandRange.lowerBound,
                        height: trackHeight - handleVerticalInset * 2
                    )
                    .position(
                        x: (loopBandRange.lowerBound + loopBandRange.upperBound) / 2,
                        y: trackHeight / 2
                    )
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .zIndex(0)
            }

            waveformBars(
                contentWidth: contentWidth,
                startX: startX,
                endX: endX,
                playheadX: playheadX,
                loopBandRange: loopBandRange
            )
            .zIndex(0)

            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: max(startX, 0))

                Rectangle()
                    .fill(Color.clear)
                    .frame(width: selectedWidth)

                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: trailingWidth)
            }
            .allowsHitTesting(false)
            .zIndex(1)

            RoundedRectangle(cornerRadius: handleCornerRadius)
                .stroke(AppColors.primary600, lineWidth: selectionBorderLineWidth)
                .frame(
                    width: max(endX - startX, handleWidth),
                    height: trackHeight - selectionBorderLineWidth
                )
                .position(x: (startX + endX) / 2, y: trackHeight / 2)
                .allowsHitTesting(false)
                .zIndex(2)

            if let playheadX {
                RoundedRectangle(cornerRadius: playheadWidth / 2)
                    .fill(Color.white)
                    .frame(width: playheadWidth, height: trackHeight - 10)
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 0)
                    .position(x: playheadX, y: trackHeight / 2)
                    .animation(.linear(duration: 0.25), value: playheadX)
                    .allowsHitTesting(false)
                    .zIndex(3)
            }

            trimHandle(direction: .left)
                .scaleEffect(activeHandleDragDirection == .left ? handlePressedScale : 1)
                .animation(
                    .spring(response: 0.28, dampingFraction: 0.7),
                    value: activeHandleDragDirection == .left
                )
                .position(
                    x: startX + handleEdgeInset + handleWidth / 2,
                    y: trackHeight / 2
                )
                .highPriorityGesture(
                    startHandleDragGesture(
                        contentWidth: contentWidth,
                        viewportWidth: viewportWidth
                    )
                )
                .zIndex(4)

            trimHandle(direction: .right)
                .scaleEffect(activeHandleDragDirection == .right ? handlePressedScale : 1)
                .animation(
                    .spring(response: 0.28, dampingFraction: 0.7),
                    value: activeHandleDragDirection == .right
                )
                .position(
                    x: endX - handleEdgeInset - handleWidth / 2,
                    y: trackHeight / 2
                )
                .highPriorityGesture(
                    endHandleDragGesture(
                        contentWidth: contentWidth,
                        viewportWidth: viewportWidth
                    )
                )
                .zIndex(4)

            if isStartOffscreen {
                followScrollButton(direction: .left)
                    .position(
                        x: followButtonCenterX(
                            for: .left,
                            visibleRange: visibleRange,
                            contentWidth: contentWidth
                        ),
                        y: trackHeight / 2
                    )
                    .zIndex(5)
            }

            if isEndOffscreen {
                followScrollButton(direction: .right)
                    .position(
                        x: followButtonCenterX(
                            for: .right,
                            visibleRange: visibleRange,
                            contentWidth: contentWidth
                        ),
                        y: trackHeight / 2
                    )
                    .zIndex(5)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .onTapGesture { location in
            onTrimInteracted()
            onSeekRequested(timeForContentX(location.x, contentWidth: contentWidth))
        }
    }

    private func loopBandXRange(
        startX: CGFloat,
        endX: CGFloat,
        contentWidth: CGFloat
    ) -> ClosedRange<CGFloat>? {
        guard let loopDirection = activeLoopDirection, duration > 0 else { return nil }

        let innerStartX = startX + handleEdgeInset + handleWidth
        let innerEndX = endX - handleEdgeInset - handleWidth
        let usableWidth = max(contentWidth - horizontalPadding * 2, 1)
        let rawLoopWidth = CGFloat(boundaryLoopDuration / duration) * usableWidth
        let loopWidth = min(rawLoopWidth, max(innerEndX - innerStartX, 0))
        guard loopWidth > 0 else { return nil }

        let bandStartX = loopDirection == .left ? innerStartX : innerEndX - loopWidth
        return bandStartX...(bandStartX + loopWidth)
    }

    private func playheadXPosition(
        startX: CGFloat,
        endX: CGFloat,
        contentWidth: CGFloat,
        loopBandRange: ClosedRange<CGFloat>?
    ) -> CGFloat? {
        guard duration > 0 else { return nil }

        if let loopBandRange, let loopRange = boundaryLoopSecondsRange() {
            guard
                playbackSeconds >= loopRange.lowerBound - 0.2,
                playbackSeconds <= loopRange.upperBound + 0.2
            else {
                return nil
            }

            let loopDuration = max(loopRange.upperBound - loopRange.lowerBound, 0.0001)
            let ratio = min(max((playbackSeconds - loopRange.lowerBound) / loopDuration, 0), 1)
            return loopBandRange.lowerBound
                + CGFloat(ratio) * (loopBandRange.upperBound - loopBandRange.lowerBound)
        }

        guard
            playbackSeconds >= startSeconds - 0.2,
            playbackSeconds <= endSeconds + 0.2
        else {
            return nil
        }

        let innerStartX = startX + handleEdgeInset + handleWidth + playheadWidth / 2
        let innerEndX = endX - handleEdgeInset - handleWidth - playheadWidth / 2
        guard innerEndX > innerStartX else { return nil }

        let clipDuration = max(endSeconds - startSeconds, 0.0001)
        let ratio = min(max((playbackSeconds - startSeconds) / clipDuration, 0), 1)
        return innerStartX + CGFloat(ratio) * (innerEndX - innerStartX)
    }

    private func boundaryLoopSecondsRange() -> ClosedRange<Double>? {
        guard let loopDirection = activeLoopDirection else { return nil }

        switch loopDirection {
        case .left:
            let upperBound = min(startSeconds + boundaryLoopDuration, endSeconds)
            guard upperBound > startSeconds else { return nil }
            return startSeconds...upperBound
        case .right:
            let lowerBound = max(endSeconds - boundaryLoopDuration, startSeconds)
            guard endSeconds > lowerBound else { return nil }
            return lowerBound...endSeconds
        }
    }

    private func handleTimeLabels(contentWidth: CGFloat) -> some View {
        let startX = xPosition(for: startSeconds, contentWidth: contentWidth)
        let endX = xPosition(for: endSeconds, contentWidth: contentWidth)

        return ZStack(alignment: .topLeading) {
            handleTimeLabel("\(startTimeText)")
                .position(
                    x: clampedLabelCenter(for: startX, contentWidth: contentWidth),
                    y: handleLabelHeight / 2
                )

            handleTimeLabel("\(endTimeText)")
                .position(
                    x: clampedLabelCenter(for: endX, contentWidth: contentWidth),
                    y: handleLabelHeight / 2
                )
        }
    }

    private func handleTimeLabel(_ text: String) -> some View {
        Text(text)
            .font(AppFont.paperlogy4Regular(size: 11))
            .foregroundStyle(.white.opacity(0.74))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: handleLabelWidth)
    }

    private func clampedLabelCenter(for x: CGFloat, contentWidth: CGFloat) -> CGFloat {
        let half = handleLabelWidth / 2
        return min(max(x, half), contentWidth - half)
    }

    private func overviewBar(width: CGFloat) -> some View {
        let safeDuration = max(duration, 0.0001)
        let usableWidth = max(width - overviewHorizontalInset * 2, 1)
        let clipDuration = min(max(currentClipDuration, 1), duration)
        let selectionWidth = min(
            max(CGFloat(clipDuration / safeDuration) * usableWidth, 14),
            usableWidth
        )

        let rawStartX = overviewHorizontalInset + CGFloat(startSeconds / safeDuration) * usableWidth
        let maxStartX = overviewHorizontalInset + usableWidth - selectionWidth
        let clampedStartX = min(max(rawStartX, overviewHorizontalInset), maxStartX)

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))

            overviewBars(width: usableWidth)
                .padding(.horizontal, overviewHorizontalInset)

            RoundedRectangle(cornerRadius: 7)
                .fill(AppColors.primary600.opacity(0.35))
                .frame(width: selectionWidth, height: overviewHeight - 8)
                .offset(x: clampedStartX)

            Rectangle()
                .fill(AppColors.primary600.opacity(0.9))
                .frame(width: 2, height: overviewHeight - 8)
                .offset(x: clampedStartX)

            Rectangle()
                .fill(AppColors.primary600.opacity(0.9))
                .frame(width: 2, height: overviewHeight - 8)
                .offset(x: clampedStartX + selectionWidth - 2)
        }
        .frame(height: overviewHeight)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    onTrimInteracted()
                    let target = timeForOverviewX(value.location.x, width: width)
                    moveSelectionCenter(to: target)
                }
                .onEnded { _ in
                    onInteractionEnded(.spectrumBar)
                }
        )
    }

    private func overviewBars(width: CGFloat) -> some View {
        let totalBarWidth: CGFloat = 4
        let count = max(Int(width / totalBarWidth), 1)

        return HStack(alignment: .center, spacing: 2) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(
                        width: 2,
                        height: 5 + abs(sin(Double(index) * 0.28)) * (overviewHeight - 10)
                    )
            }
        }
        .frame(width: width, height: overviewHeight - 4, alignment: .leading)
    }

    private func waveformBars(
        contentWidth: CGFloat,
        startX: CGFloat,
        endX: CGFloat,
        playheadX: CGFloat?,
        loopBandRange: ClosedRange<CGFloat>?
    ) -> some View {
        let usableWidth = max(contentWidth - horizontalPadding * 2, 1)
        let totalBarWidth = barWidth + barSpacing
        let barCount = max(Int(usableWidth / totalBarWidth), 1)

        return HStack(alignment: .center, spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                let barCenterX = horizontalPadding + CGFloat(index) * totalBarWidth + barWidth / 2

                Capsule()
                    .fill(
                        barColor(
                            centerX: barCenterX,
                            index: index,
                            startX: startX,
                            endX: endX,
                            playheadX: playheadX,
                            loopBandRange: loopBandRange
                        )
                    )
                    .frame(width: barWidth, height: barHeight(for: index))
            }
        }
        .frame(width: usableWidth, height: trackHeight, alignment: .leading)
        .padding(.horizontal, horizontalPadding)
    }

    private func barColor(
        centerX: CGFloat,
        index: Int,
        startX: CGFloat,
        endX: CGFloat,
        playheadX: CGFloat?,
        loopBandRange: ClosedRange<CGFloat>?
    ) -> Color {
        guard centerX >= startX, centerX <= endX else {
            return Color.white.opacity(barOpacity(for: index))
        }

        if let loopBandRange {
            guard loopBandRange.contains(centerX) else {
                return Color.white.opacity(barOpacity(for: index))
            }

            if let playheadX, centerX <= playheadX {
                return AppColors.primary600
            }
            return Color.white.opacity(0.95)
        }

        if let playheadX, centerX <= playheadX {
            return AppColors.primary600
        }

        return Color.white.opacity(0.95)
    }

    private func trimHandle(direction: HandleDirection) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: handleBodyCornerRadius)
                .fill(AppColors.primary600)

            Image(systemName: direction.systemSymbolName)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.black.opacity(0.92))
        }
        .frame(width: handleWidth, height: trackHeight - handleVerticalInset * 2)
        .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 2)
        .padding(.horizontal, 8)
        .padding(.vertical, handleVerticalInset)
        .contentShape(Rectangle())
    }

    private func secondNudgeButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.paperlogy6SemiBold(size: 11))
                .foregroundStyle(.black.opacity(0.92))
                .frame(width: nudgeButtonSize, height: nudgeButtonSize)
                .background(
                    Circle()
                        .fill(AppColors.primary600)
                )
                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func nudgeSelection(by delta: Double) {
        guard duration > 0 else { return }

        onTrimInteracted()

        if currentClipDuration >= maximumClipDuration - 0.001 {
            let clipDuration = min(max(currentClipDuration, 1), duration)
            var newStart = startSeconds + delta
            var newEnd = newStart + clipDuration

            if newStart < 0 {
                newStart = 0
                newEnd = clipDuration
            }
            if newEnd > duration {
                newEnd = duration
                newStart = max(duration - clipDuration, 0)
            }

            withAnimation(nudgeAnimation) {
                onUpdateRange(newStart, newEnd)
            }
        } else if delta < 0 {
            withAnimation(nudgeAnimation) {
                startSeconds += delta
            }
        } else {
            withAnimation(nudgeAnimation) {
                endSeconds += delta
            }
        }

        onInteractionEnded(delta < 0 ? .minusOneSecond : .plusOneSecond)
        scheduleSelectionRecenter()
    }

    private func followScrollButton(direction: HandleDirection) -> some View {
        Button {
            onTrimInteracted()
            switch direction {
            case .left:
                scrollTimelineToStart(startSeconds, animated: true)
            case .right:
                scrollTimelineToEnd(endSeconds, animated: true)
            }
        } label: {
            Image(systemName: direction.systemSymbolName)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
                .frame(width: followButtonSize, height: followButtonSize)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.62))
                )
                .overlay {
                    Circle()
                        .stroke(AppColors.primary600.opacity(0.85), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func followButtonCenterX(
        for direction: HandleDirection,
        visibleRange: ClosedRange<CGFloat>,
        contentWidth: CGFloat
    ) -> CGFloat {
        let half = followButtonSize / 2
        let rawX: CGFloat
        switch direction {
        case .left:
            rawX = visibleRange.lowerBound + followButtonInset + half
        case .right:
            rawX = visibleRange.upperBound - followButtonInset - half
        }
        return min(max(rawX, half), max(contentWidth - half, half))
    }

    private func timelineVisibleRange(
        contentWidth: CGFloat,
        fallbackViewportWidth: CGFloat
    ) -> ClosedRange<CGFloat> {
        let resolvedViewportWidth = max(
            timelineViewportWidth > 0 ? timelineViewportWidth : fallbackViewportWidth,
            1
        )
        let resolvedContentWidth = max(
            timelineContentWidth > 0 ? timelineContentWidth : contentWidth,
            resolvedViewportWidth
        )
        let maxOffset = max(resolvedContentWidth - resolvedViewportWidth, 0)
        let clampedOffset = min(max(timelineViewportOffsetX, 0), maxOffset)
        let upper = min(clampedOffset + resolvedViewportWidth, resolvedContentWidth)
        return clampedOffset...upper
    }

    private func handleTimelineViewportChanged(_ viewport: AddSearchDetailTimelineViewport) {
        let previousOffset = timelineViewportOffsetX
        timelineViewportOffsetX = viewport.contentOffsetX
        timelineViewportWidth = viewport.viewportWidth
        timelineContentWidth = viewport.contentWidth

        let didOffsetChange = abs(previousOffset - viewport.contentOffsetX) > 0.5
        guard didOffsetChange else { return }
        guard activeHandleDragDirection == nil else { return }
        guard viewport.isTracking || viewport.isDragging || viewport.isDecelerating else { return }

        scheduleTimelineScrollEndEvent()
    }

    private func scheduleTimelineScrollEndEvent() {
        timelineScrollEndWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            guard let scrollView = timelineScrollView else { return }
            if scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating {
                scheduleTimelineScrollEndEvent()
                return
            }
            onInteractionEnded(.spectrumBar)
        }
        timelineScrollEndWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }

    private func startHandleDragGesture(contentWidth: CGFloat, viewportWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(timelineCoordinateSpaceName))
            .onChanged { value in
                if startDragBase == nil {
                    startDragBase = startSeconds
                    onTrimInteracted()
                    scheduleHandleLoopActivation(direction: .left)
                }
                activateDrag(direction: .left, contentWidth: contentWidth)
                activeHandleDragTranslation = value.translation.width
                if isBeyondTapThreshold(value.translation) {
                    cancelHandleLoop()
                    onHandleDragMovementChanged(true)
                }
                updateAutoScrollVelocity(locationX: value.location.x, viewportWidth: viewportWidth)
                applyActiveHandleDrag()
            }
            .onEnded { value in
                let didActivateLoop = activeLoopDirection == .left
                let isTap = !isBeyondTapThreshold(value.translation)
                cancelHandleLoop()
                onHandleDragMovementChanged(false)
                startDragBase = nil
                onInteractionEnded(.left)
                endActiveHandleDrag()
                if isTap {
                    if !didActivateLoop {
                        onSeekRequested(startSeconds)
                    }
                } else {
                    scheduleSelectionRecenter()
                }
            }
    }

    private func endHandleDragGesture(contentWidth: CGFloat, viewportWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(timelineCoordinateSpaceName))
            .onChanged { value in
                if endDragBase == nil {
                    endDragBase = endSeconds
                    onTrimInteracted()
                    scheduleHandleLoopActivation(direction: .right)
                }
                activateDrag(direction: .right, contentWidth: contentWidth)
                activeHandleDragTranslation = value.translation.width
                if isBeyondTapThreshold(value.translation) {
                    cancelHandleLoop()
                    onHandleDragMovementChanged(true)
                }
                updateAutoScrollVelocity(locationX: value.location.x, viewportWidth: viewportWidth)
                applyActiveHandleDrag()
            }
            .onEnded { value in
                cancelHandleLoop()
                onHandleDragMovementChanged(false)
                endDragBase = nil
                onInteractionEnded(.right)
                endActiveHandleDrag()
                if isBeyondTapThreshold(value.translation) {
                    scheduleSelectionRecenter()
                }
            }
    }

    private func isBeyondTapThreshold(_ translation: CGSize) -> Bool {
        abs(translation.width) >= handleTapMaxTranslation
            || abs(translation.height) >= handleTapMaxTranslation
    }

    private func scheduleHandleLoopActivation(direction: HandleDirection) {
        handleLoopWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            guard activeHandleDragDirection == direction else { return }
            guard abs(activeHandleDragTranslation) < handleTapMaxTranslation else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                activeLoopDirection = direction
            }
            onHandleLoopActivated(direction == .left ? .left : .right)
        }
        handleLoopWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + handleLoopActivationDelay,
            execute: workItem
        )
    }

    private func cancelHandleLoop() {
        handleLoopWorkItem?.cancel()
        handleLoopWorkItem = nil
        if activeLoopDirection != nil {
            withAnimation(.easeInOut(duration: 0.2)) {
                activeLoopDirection = nil
            }
            onHandleLoopDeactivated()
        }
    }

    private func activateDrag(direction: HandleDirection, contentWidth: CGFloat) {
        if activeHandleDragDirection != direction {
            activeHandleDragDirection = direction
            activeHandleDragTranslation = 0
            autoScrollAdditionalSeconds = 0
            selectionRecenterWorkItem?.cancel()
            selectionRecenterWorkItem = nil
        }
        activeHandleContentWidth = contentWidth
    }

    private func scheduleSelectionRecenter() {
        selectionRecenterWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            guard activeHandleDragDirection == nil else { return }
            if let scrollView = timelineScrollView,
               scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating {
                return
            }
            scrollTimelineToCenterSelection(animated: true)
        }
        selectionRecenterWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + selectionRecenterDelay, execute: workItem)
    }

    private func scrollTimelineToCenterSelection(animated: Bool) {
        guard let scrollView = timelineScrollView else { return }
        let contentWidth = resolvedTimelineContentWidth(for: scrollView)
        let startX = xPosition(for: startSeconds, contentWidth: contentWidth)
        let endX = xPosition(for: endSeconds, contentWidth: contentWidth)
        let offsetX = (startX + endX) / 2 - scrollView.bounds.width / 2
        setTimelineOffset(offsetX, in: scrollView, animated: animated)
    }

    private func endActiveHandleDrag() {
        activeHandleDragDirection = nil
        activeHandleDragTranslation = 0
        autoScrollAdditionalSeconds = 0
        stopAutoScrollTimer()
    }

    private func applyActiveHandleDrag() {
        guard let direction = activeHandleDragDirection else { return }
        let deltaSeconds = seconds(
            forTranslation: activeHandleDragTranslation,
            contentWidth: activeHandleContentWidth
        )

        switch direction {
        case .left:
            startSeconds = (startDragBase ?? startSeconds) + deltaSeconds + autoScrollAdditionalSeconds
        case .right:
            endSeconds = (endDragBase ?? endSeconds) + deltaSeconds + autoScrollAdditionalSeconds
        }
    }

    private func updateAutoScrollVelocity(locationX: CGFloat, viewportWidth: CGFloat) {
        autoScrollVelocity = autoScrollVelocityForEdge(
            locationX: locationX,
            viewportWidth: viewportWidth
        )

        if abs(autoScrollVelocity) > 0.001 {
            startAutoScrollTimerIfNeeded()
        } else {
            stopAutoScrollTimer()
        }
    }

    private func autoScrollVelocityForEdge(locationX: CGFloat, viewportWidth: CGFloat) -> CGFloat {
        guard viewportWidth > autoScrollEdgeThreshold * 2 else { return 0 }

        if locationX < autoScrollEdgeThreshold {
            let ratio = (autoScrollEdgeThreshold - locationX) / autoScrollEdgeThreshold
            return -autoScrollMaxVelocity * ratio
        }

        let rightEdgeStart = viewportWidth - autoScrollEdgeThreshold
        if locationX > rightEdgeStart {
            let ratio = (locationX - rightEdgeStart) / autoScrollEdgeThreshold
            return autoScrollMaxVelocity * ratio
        }

        return 0
    }

    private func startAutoScrollTimerIfNeeded() {
        guard autoScrollTimer == nil else { return }

        autoScrollLastTick = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1 / 60, repeats: true) { _ in
            performAutoScrollTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        autoScrollTimer = timer
    }

    private func stopAutoScrollTimer() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
        autoScrollVelocity = 0
        autoScrollLastTick = nil
    }

    private func performAutoScrollTick() {
        guard
            abs(autoScrollVelocity) > 0.001,
            activeHandleDragDirection != nil,
            let scrollView = timelineScrollView
        else {
            return
        }

        let now = CACurrentMediaTime()
        guard let lastTick = autoScrollLastTick else {
            autoScrollLastTick = now
            return
        }
        autoScrollLastTick = now

        let deltaTime = min(max(now - lastTick, 0), 0.05)
        let currentOffset = scrollView.contentOffset.x
        let maxOffset = max(scrollView.contentSize.width - scrollView.bounds.width, 0)
        let targetOffset = min(
            max(currentOffset + autoScrollVelocity * CGFloat(deltaTime), 0),
            maxOffset
        )

        let movedOffset = targetOffset - currentOffset
        guard abs(movedOffset) > 0.0001 else { return }

        scrollView.setContentOffset(CGPoint(x: targetOffset, y: scrollView.contentOffset.y), animated: false)
        timelineViewportOffsetX = targetOffset
        timelineViewportWidth = scrollView.bounds.width
        timelineContentWidth = scrollView.contentSize.width
        autoScrollAdditionalSeconds += seconds(
            forTranslation: movedOffset,
            contentWidth: activeHandleContentWidth
        )
        applyActiveHandleDrag()
    }

    private func seconds(forTranslation translation: CGFloat, contentWidth: CGFloat) -> Double {
        guard duration > 0 else { return 0 }
        let usableWidth = max(contentWidth - horizontalPadding * 2, 1)
        return Double(translation / usableWidth) * duration
    }

    private func xPosition(for seconds: Double, contentWidth: CGFloat) -> CGFloat {
        guard duration > 0 else { return horizontalPadding }
        let clampedSeconds = min(max(seconds, 0), duration)
        let usableWidth = max(contentWidth - horizontalPadding * 2, 1)
        let ratio = clampedSeconds / duration
        return horizontalPadding + CGFloat(ratio) * usableWidth
    }

    private func barHeight(for index: Int) -> CGFloat {
        let primary = abs(sin(Double(index) * 0.43))
        let secondary = abs(cos(Double(index) * 0.17))
        let tertiary = abs(sin(Double(index) * 0.09))
        let mix = min(primary * 0.55 + secondary * 0.3 + tertiary * 0.25, 1)
        return 14 + CGFloat(mix) * (trackHeight - 26)
    }

    private func barOpacity(for index: Int) -> Double {
        let pulse = abs(sin(Double(index) * 0.21))
        return 0.18 + pulse * 0.38
    }

    private var currentClipDuration: Double {
        max(endSeconds - startSeconds, 0)
    }

    private func timeForContentX(_ x: CGFloat, contentWidth: CGFloat) -> Double {
        guard duration > 0 else { return 0 }
        let usableWidth = max(contentWidth - horizontalPadding * 2, 1)
        let clamped = min(max(x - horizontalPadding, 0), usableWidth)
        return Double(clamped / usableWidth) * duration
    }

    private func timeForOverviewX(_ x: CGFloat, width: CGFloat) -> Double {
        guard duration > 0 else { return 0 }
        let usableWidth = max(width - overviewHorizontalInset * 2, 1)
        let clamped = min(max(x - overviewHorizontalInset, 0), usableWidth)
        return Double(clamped / usableWidth) * duration
    }

    private func moveSelectionCenter(to seconds: Double) {
        guard duration > 0 else { return }

        let clipDuration = min(duration, max(currentClipDuration, 1))
        var newStart = seconds - clipDuration / 2
        var newEnd = seconds + clipDuration / 2

        if newStart < 0 {
            newStart = 0
            newEnd = clipDuration
        }
        if newEnd > duration {
            newEnd = duration
            newStart = max(duration - clipDuration, 0)
        }

        onUpdateRange(newStart, newEnd)
        scrollTimelineToStart(newStart, animated: false)
    }

    private func scrollTimelineToStart(_ seconds: Double, animated: Bool) {
        guard let scrollView = timelineScrollView else { return }
        let contentWidth = resolvedTimelineContentWidth(for: scrollView)
        let targetX = xPosition(for: seconds, contentWidth: contentWidth)
        let offsetX = max(targetX - horizontalPadding, 0)
        setTimelineOffset(offsetX, in: scrollView, animated: animated)
    }

    private func scrollTimelineToEnd(_ seconds: Double, animated: Bool) {
        guard let scrollView = timelineScrollView else { return }
        let contentWidth = resolvedTimelineContentWidth(for: scrollView)
        let targetX = xPosition(for: seconds, contentWidth: contentWidth)
        let offsetX = max(targetX - scrollView.bounds.width + horizontalPadding, 0)
        setTimelineOffset(offsetX, in: scrollView, animated: animated)
    }

    private func resolvedTimelineContentWidth(for scrollView: UIScrollView) -> CGFloat {
        max(
            CGFloat(max(duration, 1)) * pointsPerSecond + horizontalPadding * 2,
            max(scrollView.contentSize.width, scrollView.bounds.width)
        )
    }

    private func setTimelineOffset(_ offsetX: CGFloat, in scrollView: UIScrollView, animated: Bool) {
        let maxOffset = max(scrollView.contentSize.width - scrollView.bounds.width, 0)
        let clampedOffset = min(max(offsetX, 0), maxOffset)
        scrollView.setContentOffset(
            CGPoint(x: clampedOffset, y: scrollView.contentOffset.y),
            animated: animated
        )
        timelineViewportOffsetX = clampedOffset
        timelineViewportWidth = scrollView.bounds.width
        timelineContentWidth = scrollView.contentSize.width
    }

    private enum HandleDirection {
        case left
        case right

        var systemSymbolName: String {
            switch self {
            case .left:
                return "chevron.left"
            case .right:
                return "chevron.right"
            }
        }
    }
}

private struct AddSearchDetailTimelineViewport {
    let contentOffsetX: CGFloat
    let viewportWidth: CGFloat
    let contentWidth: CGFloat
    let isTracking: Bool
    let isDragging: Bool
    let isDecelerating: Bool
}

private struct AddSearchDetailScrollViewResolver: UIViewRepresentable {
    let onResolve: (UIScrollView) -> Void
    let onViewportChange: (AddSearchDetailTimelineViewport) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            context.coordinator.resolve(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.resolve(from: uiView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onResolve: onResolve,
            onViewportChange: onViewportChange
        )
    }

    final class Coordinator {
        private let onResolve: (UIScrollView) -> Void
        private let onViewportChange: (AddSearchDetailTimelineViewport) -> Void
        private weak var resolvedScrollView: UIScrollView?
        private var observations: [NSKeyValueObservation] = []

        init(
            onResolve: @escaping (UIScrollView) -> Void,
            onViewportChange: @escaping (AddSearchDetailTimelineViewport) -> Void
        ) {
            self.onResolve = onResolve
            self.onViewportChange = onViewportChange
        }

        func resolve(from view: UIView) {
            var current: UIView? = view.superview
            var candidates: [UIScrollView] = []
            while let candidate = current {
                if let scrollView = candidate as? UIScrollView {
                    candidates.append(scrollView)
                }
                current = candidate.superview
            }

            guard let scrollView = preferredScrollView(from: candidates) else { return }
            if resolvedScrollView === scrollView {
                publishViewport(for: scrollView)
                return
            }

            resolvedScrollView = scrollView
            observe(scrollView)
            onResolve(scrollView)
            publishViewport(for: scrollView)
        }

        private func preferredScrollView(from candidates: [UIScrollView]) -> UIScrollView? {
            if let horizontalCandidate = candidates.first(where: {
                $0.contentSize.width > $0.bounds.width + 1 || ($0.bounds.height > 0 && $0.bounds.height <= 220)
            }) {
                return horizontalCandidate
            }
            return candidates.first
        }

        private func observe(_ scrollView: UIScrollView) {
            observations.forEach { $0.invalidate() }
            observations.removeAll()

            let contentOffsetObservation = scrollView.observe(
                \.contentOffset,
                options: [.new]
            ) { [weak self] observedScrollView, _ in
                self?.publishViewport(for: observedScrollView)
            }
            let contentSizeObservation = scrollView.observe(
                \.contentSize,
                options: [.new]
            ) { [weak self] observedScrollView, _ in
                self?.publishViewport(for: observedScrollView)
            }
            let boundsObservation = scrollView.observe(
                \.bounds,
                options: [.new]
            ) { [weak self] observedScrollView, _ in
                self?.publishViewport(for: observedScrollView)
            }

            observations = [
                contentOffsetObservation,
                contentSizeObservation,
                boundsObservation
            ]
        }

        private func publishViewport(for scrollView: UIScrollView) {
            let snapshot = AddSearchDetailTimelineViewport(
                contentOffsetX: scrollView.contentOffset.x,
                viewportWidth: scrollView.bounds.width,
                contentWidth: scrollView.contentSize.width,
                isTracking: scrollView.isTracking,
                isDragging: scrollView.isDragging,
                isDecelerating: scrollView.isDecelerating
            )
            DispatchQueue.main.async {
                self.onViewportChange(snapshot)
            }
        }
    }
}

