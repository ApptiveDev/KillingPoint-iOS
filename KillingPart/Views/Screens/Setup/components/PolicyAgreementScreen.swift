import SwiftUI

struct PolicyAgreementScreen: View {
    @ObservedObject var viewModel: InitialSetupFlowViewModel
    @State private var activeDocument: PolicyDocumentType?

    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding = max(AppSpacing.m, geometry.size.width * 0.08)
            let topPadding = geometry.safeAreaInsets.top + AppSpacing.l
            let bottomPadding = geometry.safeAreaInsets.bottom + AppSpacing.l
            let titleTopOffset = max(topPadding + AppSpacing.xl, geometry.size.height * 0.18)

            ZStack {
                LoginBackgroundVideoView()
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [Color.black.opacity(0.36), Color.black.opacity(0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Image("loginTitle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(geometry.size.width * 0.62, 280))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, titleTopOffset)

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: AppSpacing.m) {
                        policyRow(
                            title: "서비스 이용약관",
                            isChecked: viewModel.isServiceTermsAgreed,
                            onTap: {
                                viewModel.isServiceTermsAgreed.toggle()
                            },
                            onSeeFullTextTap: {
                                activeDocument = .serviceTerms
                            }
                        )

                        policyRow(
                            title: "개인정보 처리방침",
                            isChecked: viewModel.isPrivacyAgreed,
                            onTap: {
                                viewModel.isPrivacyAgreed.toggle()
                            },
                            onSeeFullTextTap: {
                                activeDocument = .privacy
                            }
                        )

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(AppFont.paperlogy4Regular(size: 13))
                                .foregroundStyle(.red.opacity(0.95))
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, AppSpacing.xl)

                    PrimaryButton(
                        title: "전체 동의 후 시작하기",
                        isLoading: viewModel.isLoading
                    ) {
                        Task {
                            await viewModel.submitPolicyAgreement()
                        }
                    }
                    .disabled(!viewModel.canSubmitPolicyAgreement || viewModel.isLoading)
                    .opacity((viewModel.canSubmitPolicyAgreement && !viewModel.isLoading) ? 1 : 0.45)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, bottomPadding)
                }
            }
        }
        .sheet(item: $activeDocument) { documentType in
            PolicyDocumentSheet(documentType: documentType)
                .preferredColorScheme(.dark)
        }
    }

    private func policyRow(
        title: String,
        isChecked: Bool,
        onTap: @escaping () -> Void,
        onSeeFullTextTap: @escaping () -> Void
    ) -> some View {
        HStack(spacing: AppSpacing.s) {
            Button(action: onTap) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isChecked ? AppColors.primary600 : .white.opacity(0.75))
            }
            .buttonStyle(.plain)

            Text(title)
                .font(AppFont.paperlogy4Regular(size: 15))
                .foregroundStyle(.white.opacity(0.9))

            Spacer(minLength: AppSpacing.s)

            Button(action: onSeeFullTextTap) {
                Text("전문확인")
                    .font(AppFont.paperlogy4Regular(size: 14))
                    .underline(true, color: AppColors.primary600.opacity(0.92))
                    .foregroundStyle(AppColors.primary600.opacity(0.92))
            }
            .buttonStyle(.plain)
        }
    }
}

private enum PolicyDocumentType: String, Identifiable {
    case serviceTerms
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .serviceTerms:
            return "서비스 이용약관"
        case .privacy:
            return "개인정보 처리방침"
        }
    }

    var fullText: String {
        switch self {
        case .serviceTerms:
            return PolicyDocumentContent.serviceTerms
        case .privacy:
            return PolicyDocumentContent.privacyPolicy
        }
    }
}

private struct PolicyDocumentSheet: View {
    @Environment(\.dismiss) private var dismiss

    let documentType: PolicyDocumentType

    private enum LineStyle {
        case article
        case numbered
        case numberedContinuation
        case subNumbered
        case subNumberedContinuation
        case body
        case blank
    }

    private struct StyledLine: Identifiable {
        let id: Int
        let text: String
        let style: LineStyle
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(styledLines) { line in
                        if line.style == .blank {
                            Color.clear
                                .frame(height: 10)
                        } else {
                            Text(line.text)
                                .font(font(for: line.style))
                                .foregroundStyle(.white.opacity(0.92))
                                .lineSpacing(4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, leadingInset(for: line.style))
                                .padding(.top, topInset(for: line.style))
                        }
                    }
                }
                .padding(AppSpacing.l)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(documentType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }

    private var styledLines: [StyledLine] {
        let lines = normalizedDocumentText.components(separatedBy: .newlines)
        var result: [StyledLine] = []
        var previousStyle: LineStyle = .blank

        for (index, rawLine) in lines.enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            let baseStyle = style(for: trimmed)

            let resolvedStyle: LineStyle
            if baseStyle == .body {
                switch previousStyle {
                case .numbered, .numberedContinuation:
                    resolvedStyle = .numberedContinuation
                case .subNumbered, .subNumberedContinuation:
                    resolvedStyle = .subNumberedContinuation
                default:
                    resolvedStyle = .body
                }
            } else {
                resolvedStyle = baseStyle
            }

            result.append(
                StyledLine(
                    id: index,
                    text: trimmed,
                    style: resolvedStyle
                )
            )
            previousStyle = resolvedStyle
        }
        return result
    }

    private var normalizedDocumentText: String {
        var text = documentType.fullText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "## ", with: "")
        text = text.replacingOccurrences(
            of: #"\)(\d+\.)"#,
            with: ")\n$1",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"(\d+년)(\d+\.)"#,
            with: "$1\n$2",
            options: .regularExpression
        )
        return text
    }

    private func style(for line: String) -> LineStyle {
        if line.isEmpty {
            return .blank
        }
        if line.range(of: #"^제\d+조"#, options: .regularExpression) != nil || line == "부칙" {
            return .article
        }
        if line.range(of: #"^\d+[.)]"#, options: .regularExpression) != nil {
            return .numbered
        }
        if line.range(of: #"^[가-하][.)]"#, options: .regularExpression) != nil {
            return .subNumbered
        }
        return .body
    }

    private func font(for style: LineStyle) -> Font {
        switch style {
        case .article:
            return AppFont.paperlogy7Bold(size: 18)
        case .numbered:
            return AppFont.paperlogy5Medium(size: 14)
        case .numberedContinuation:
            return AppFont.paperlogy5Medium(size: 14)
        case .subNumbered:
            return AppFont.paperlogy5Medium(size: 13)
        case .subNumberedContinuation:
            return AppFont.paperlogy5Medium(size: 13)
        case .body:
            return AppFont.paperlogy4Regular(size: 13)
        case .blank:
            return AppFont.paperlogy4Regular(size: 13)
        }
    }

    private func leadingInset(for style: LineStyle) -> CGFloat {
        switch style {
        case .article:
            return 0
        case .numbered:
            return 10
        case .numberedContinuation:
            return 30
        case .subNumbered:
            return 20
        case .subNumberedContinuation:
            return 40
        case .body, .blank:
            return 0
        }
    }

    private func topInset(for style: LineStyle) -> CGFloat {
        switch style {
        case .article:
            return 12
        case .numbered:
            return 6
        case .numberedContinuation:
            return 2
        case .subNumbered:
            return 4
        case .subNumberedContinuation:
            return 2
        case .body:
            return 3
        case .blank:
            return 0
        }
    }
}
