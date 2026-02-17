import SwiftUI

struct AddSearchFieldView: View {
    @Binding var query: String
    let hasQuery: Bool
    let onSubmit: () -> Void
    let onQueryChanged: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.7))

            TextField("곡 또는 아티스트 검색", text: $query)
                .font(AppFont.paperlogy5Medium(size: 15))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.search)
                .onSubmit {
                    onSubmit()
                }
                .onChange(of: query) { _ in
                    onQueryChanged()
                }

            if hasQuery {
                Button {
                    onClear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.75))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.primary600.opacity(0.45), lineWidth: 1)
        }
    }
}
