import SwiftUI

struct AddSearchDetailCommentSection: View {
    @ObservedObject var viewModel: AddSearchDetailViewModel

    private let scopeOptions: [DiaryScope] = [.private, .killingPart, .public]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            commentEditor
            scopeSelector
        }
        .padding(AppSpacing.m)
    }

    private var scopeSelector: some View {
        HStack(alignment: .center, spacing: AppSpacing.xs) {
            
            Image(systemName: "globe")
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
                    Text("이 음악의 킬링파트와 감상을 자유롭게 남겨주세요.")
                        .font(AppFont.paperlogy4Regular(size: 14))
                        .foregroundStyle(.white.opacity(0.38))
                        .padding(.horizontal, AppSpacing.s)
                        .padding(.vertical, 14)
                }

                TextEditor(text: $viewModel.diaryContent)
                    .font(AppFont.paperlogy4Regular(size: 14))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, AppSpacing.xs)
                    .frame(minHeight: 190)
            }
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
        }
    }
}
