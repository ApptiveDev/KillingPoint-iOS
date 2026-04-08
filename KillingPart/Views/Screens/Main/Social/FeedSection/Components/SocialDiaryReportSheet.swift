import SwiftUI

struct SocialDiaryReportSheet: View {
    @Binding var reportReason: String
    let isSubmitting: Bool
    let errorMessage: String?
    let onCancel: () -> Void
    let onSubmit: () -> Void
    @FocusState private var isReasonFocused: Bool

    private let maxReportLength = 200

    var body: some View {
        VStack(spacing: AppSpacing.m) {
            Text("불편하거나, 부적절한 콘텐츠를 발견하셨나요?\n아래에 신고 사유를 작성해주세요.")
                .font(AppFont.paperlogy5Medium(size: 14))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            reportReasonEditor

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(AppFont.paperlogy4Regular(size: 12))
                    .foregroundStyle(Color(hex: "#FF5A5A"))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            actionButtons
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.top, AppSpacing.l)
        .padding(.bottom, AppSpacing.m)
        .presentationDetents([.height(460), .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isSubmitting)
        .preferredColorScheme(.dark)
        .onChange(of: reportReason) { newValue in
            if newValue.count > maxReportLength {
                reportReason = String(newValue.prefix(maxReportLength))
            }
        }
    }

    private var reportReasonEditor: some View {
        VStack(alignment: .trailing, spacing: AppSpacing.xs) {
            ZStack(alignment: .topLeading) {
                if reportReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("신고 사유를 입력해주세요.")
                        .font(AppFont.paperlogy4Regular(size: 14))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .padding(.horizontal, AppSpacing.s)
                        .padding(.vertical, AppSpacing.s)
                }

                TextEditor(text: $reportReason)
                    .font(AppFont.paperlogy4Regular(size: 14))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .focused($isReasonFocused)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, AppSpacing.xs)
                    .frame(minHeight: 180)
            }
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }

            Text("\(reportReason.count)/\(maxReportLength)")
                .font(AppFont.paperlogy4Regular(size: 11))
                .foregroundStyle(Color.white.opacity(0.6))
        }
    }

    private var actionButtons: some View {
        HStack(spacing: AppSpacing.s) {
            Button {
                isReasonFocused = false
                onCancel()
            } label: {
                Text("돌아가기")
                    .font(AppFont.paperlogy5Medium(size: 14))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)
            .opacity(isSubmitting ? 0.72 : 1)

            Button {
                isReasonFocused = false
                onSubmit()
            } label: {
                Group {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("신고하기")
                            .font(AppFont.paperlogy5Medium(size: 14))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color(hex: "#FF5A5A"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)
            .opacity(isSubmitting ? 0.72 : 1)
        }
    }
}
