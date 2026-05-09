import SwiftUI

enum PolicyDocumentType: String, Identifiable {
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

struct PolicyDocumentView: View {
    @Environment(\.dismiss) private var dismiss

    let documentType: PolicyDocumentType
    let showsCloseButton: Bool
    let embedsInNavigationStack: Bool

    init(
        documentType: PolicyDocumentType,
        showsCloseButton: Bool = false,
        embedsInNavigationStack: Bool = false
    ) {
        self.documentType = documentType
        self.showsCloseButton = showsCloseButton
        self.embedsInNavigationStack = embedsInNavigationStack
    }

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
        Group {
            if embedsInNavigationStack {
                NavigationStack {
                    content
                }
            } else {
                content
            }
        }
    }

    private var content: some View {
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
            if showsCloseButton {
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
