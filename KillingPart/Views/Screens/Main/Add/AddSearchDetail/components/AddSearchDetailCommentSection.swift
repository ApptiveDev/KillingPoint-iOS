import SwiftUI
import UIKit

struct AddSearchDetailCommentSection: View {
    @ObservedObject var viewModel: AddSearchDetailViewModel
    @FocusState private var isCommentEditorFocused: Bool

    private let scopeOptions: [DiaryScope] = [.private, .killingPart, .public]
    private static let todayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()

    private var todayText: String {
        Self.todayFormatter.string(from: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            commentEditor
            scopeSelector
        }
        .padding(AppSpacing.m)
        .contentShape(Rectangle())
        .onTapGesture {
            dismissKeyboard()
        }
    }

    private var scopeSelector: some View {
        HStack(alignment: .center, spacing: AppSpacing.xs) {
            Image(systemName: scopeIconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
            Text("공개상태:")
                .font(AppFont.paperlogy5Medium(size: 14))
                .foregroundStyle(.white.opacity(0.8))

            Menu {
                ForEach(scopeOptions) { scope in
                    Button {
                        viewModel.selectedScope = scope
                    } label: {
                        HStack {
                            Text(scope.addSearchDetailDisplayName)
                            if viewModel.selectedScope == scope {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: AppSpacing.s) {
                    Text(viewModel.selectedScope.addSearchDetailDisplayName)
                        .font(AppFont.paperlogy5Medium(size: 14))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, AppSpacing.s)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var commentEditor: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            ZStack(alignment: .topLeading) {
                if viewModel.diaryContent.isEmpty {
                    Text("코멘트 추가...")
                        .font(AppFont.paperlogy4Regular(size: 14))
                        .foregroundStyle(.white.opacity(0.38))
                        .padding(.horizontal, AppSpacing.s)
                        .padding(.vertical, 14)
                }

                TextEditor(text: $viewModel.diaryContent)
                    .font(AppFont.paperlogy4Regular(size: 14))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .focused($isCommentEditorFocused)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, AppSpacing.xs)
                    .padding(.bottom, AppSpacing.l)
                    .frame(minHeight: 190)
            }
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
            .overlay(alignment: .bottomLeading) {
                Text(todayText)
                    .font(AppFont.paperlogy4Regular(size: 12))
                    .foregroundStyle(.white.opacity(0.52))
                    .padding(.leading, AppSpacing.s)
                    .padding(.bottom, AppSpacing.s)
            }
        }
    }

    private var scopeIconName: String {
        switch viewModel.selectedScope {
        case .private:
            return "lock.fill"
        case .killingPart:
            return "music.note"
        case .public:
            return "globe"
        }
    }

    private func dismissKeyboard() {
        isCommentEditorFocused = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
