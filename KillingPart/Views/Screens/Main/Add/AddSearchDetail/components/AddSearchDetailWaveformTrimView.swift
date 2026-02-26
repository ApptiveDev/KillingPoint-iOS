import SwiftUI
import UIKit

struct AddSearchDetailWaveformTrimView: View {
    @Binding var startSeconds: Double
    @Binding var endSeconds: Double
    let duration: Double
    let startTimeText: String
    let endTimeText: String
    let onUpdateRange: (_ start: Double, _ end: Double) -> Void

    private let horizontalPadding: CGFloat = 18
    private let pointsPerSecond: CGFloat = 18
    private let trackHeight: CGFloat = 104
    private let handleLabelHeight: CGFloat = 18
    private let handleLabelWidth: CGFloat = 76
    private let overviewHeight: CGFloat = 24
    private let overviewHorizontalInset: CGFloat = 8
    private let barWidth: CGFloat = 4
    private let barSpacing: CGFloat = 3
    private let handleWidth: CGFloat = 34
    private let handleCornerRadius: CGFloat = 14
    private let autoScrollEdgeThreshold: CGFloat = 52
    private let autoScrollMaxVelocity: CGFloat = 260
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
                }
                .coordinateSpace(name: timelineCoordinateSpaceName)
                .background {
                    AddSearchDetailScrollViewResolver { scrollView in
                        if timelineScrollView !== scrollView {
                            timelineScrollView = scrollView
                        }
                    }
                }

                overviewBar(width: viewportWidth)
            }
        }
        .onDisappear {
            stopAutoScrollTimer()
        }
    }

    private func trimTrack(contentWidth: CGFloat, viewportWidth: CGFloat) -> some View {
        let startX = xPosition(for: startSeconds, contentWidth: contentWidth)
        let endX = xPosition(for: endSeconds, contentWidth: contentWidth)
        let selectedWidth = max(endX - startX, 1)
        let trailingWidth = max(contentWidth - endX, 0)

        return ZStack(alignment: .leading) {
            waveformBars(contentWidth: contentWidth)
                .zIndex(0)

            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: max(startX, 0))

                Rectangle()
                    .fill(AppColors.primary600.opacity(0.25))
                    .frame(width: selectedWidth)

                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: trailingWidth)
            }
            .allowsHitTesting(false)
            .zIndex(1)

            trimHandle(direction: .left)
                .position(x: startX, y: trackHeight / 2)
                .highPriorityGesture(
                    startHandleDragGesture(
                        contentWidth: contentWidth,
                        viewportWidth: viewportWidth
                    )
                )
                .zIndex(4)

            trimHandle(direction: .right)
                .position(x: endX, y: trackHeight / 2)
                .highPriorityGesture(
                    endHandleDragGesture(
                        contentWidth: contentWidth,
                        viewportWidth: viewportWidth
                    )
                )
                .zIndex(4)
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
                    let target = timeForOverviewX(value.location.x, width: width)
                    moveSelectionCenter(to: target)
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

    private func waveformBars(contentWidth: CGFloat) -> some View {
        let usableWidth = max(contentWidth - horizontalPadding * 2, 1)
        let totalBarWidth = barWidth + barSpacing
        let barCount = max(Int(usableWidth / totalBarWidth), 1)

        return HStack(alignment: .center, spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(barOpacity(for: index)))
                    .frame(width: barWidth, height: barHeight(for: index))
            }
        }
        .frame(width: usableWidth, height: trackHeight, alignment: .leading)
        .padding(.horizontal, horizontalPadding)
    }

    private func trimHandle(direction: HandleDirection) -> some View {
        let roundedSide: AddSearchDetailHandleRoundedSide = direction == .left ? .left : .right

        return ZStack {
            Rectangle()
                .fill(AppColors.primary600)

            Image(systemName: direction.systemSymbolName)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.black.opacity(0.92))
        }
        .frame(width: handleWidth, height: trackHeight)
        .clipShape(
            AddSearchDetailHandleShape(
                roundedSide: roundedSide,
                radius: handleCornerRadius
            )
        )
        .overlay {
            AddSearchDetailHandleShape(
                roundedSide: roundedSide,
                radius: handleCornerRadius
            )
            .stroke(Color.white.opacity(0.82), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 2)
    }

    private func startHandleDragGesture(contentWidth: CGFloat, viewportWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(timelineCoordinateSpaceName))
            .onChanged { value in
                if startDragBase == nil {
                    startDragBase = startSeconds
                }
                activateDrag(direction: .left, contentWidth: contentWidth)
                activeHandleDragTranslation = value.translation.width
                updateAutoScrollVelocity(locationX: value.location.x, viewportWidth: viewportWidth)
                applyActiveHandleDrag()
            }
            .onEnded { _ in
                startDragBase = nil
                endActiveHandleDrag()
            }
    }

    private func endHandleDragGesture(contentWidth: CGFloat, viewportWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(timelineCoordinateSpaceName))
            .onChanged { value in
                if endDragBase == nil {
                    endDragBase = endSeconds
                }
                activateDrag(direction: .right, contentWidth: contentWidth)
                activeHandleDragTranslation = value.translation.width
                updateAutoScrollVelocity(locationX: value.location.x, viewportWidth: viewportWidth)
                applyActiveHandleDrag()
            }
            .onEnded { _ in
                endDragBase = nil
                endActiveHandleDrag()
            }
    }

    private func activateDrag(direction: HandleDirection, contentWidth: CGFloat) {
        if activeHandleDragDirection != direction {
            activeHandleDragDirection = direction
            activeHandleDragTranslation = 0
            autoScrollAdditionalSeconds = 0
        }
        activeHandleContentWidth = contentWidth
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

private enum AddSearchDetailHandleRoundedSide {
    case left
    case right
}

private struct AddSearchDetailScrollViewResolver: UIViewRepresentable {
    let onResolve: (UIScrollView) -> Void

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
        Coordinator(onResolve: onResolve)
    }

    final class Coordinator {
        private let onResolve: (UIScrollView) -> Void
        private weak var resolvedScrollView: UIScrollView?

        init(onResolve: @escaping (UIScrollView) -> Void) {
            self.onResolve = onResolve
        }

        func resolve(from view: UIView) {
            var current: UIView? = view.superview
            while let candidate = current {
                if let scrollView = candidate as? UIScrollView {
                    guard resolvedScrollView !== scrollView else { return }
                    resolvedScrollView = scrollView
                    onResolve(scrollView)
                    return
                }
                current = candidate.superview
            }
        }
    }
}

private struct AddSearchDetailHandleShape: Shape {
    let roundedSide: AddSearchDetailHandleRoundedSide
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let corners: UIRectCorner
        switch roundedSide {
        case .left:
            corners = [.topLeft, .bottomLeft]
        case .right:
            corners = [.topRight, .bottomRight]
        }

        let bezierPath = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(bezierPath.cgPath)
    }
}
