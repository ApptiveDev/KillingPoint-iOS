import SwiftUI

struct MyCollectionProfileTagSectionView: View {
    let displayTag: String
    let isEditingTag: Bool
    @Binding var tagDraft: String
    let isProcessing: Bool
    let isTagFieldFocused: FocusState<Bool>.Binding
    let helperMessage: String?
    let helperColor: Color?
    let onBeginEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isEditingTag {
                HStack(spacing: 8) {
                    Text("@")
                        .font(AppFont.paperlogy3Light(size: 14))
                        .foregroundStyle(Color.kpPrimary)

                    TextField("태그를 입력해 주세요", text: $tagDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(AppFont.paperlogy4Regular(size: 14))
                        .foregroundStyle(Color.kpPrimary)
                        .focused(isTagFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            isTagFieldFocused.wrappedValue = false
                        }

                    Spacer(minLength: 0)

                    Image(systemName: "pencil.line")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.kpPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.s)
                .padding(.vertical, AppSpacing.xs)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.primary600.opacity(0.9), lineWidth: 1.2)
                }
            } else {
                Button(action: onBeginEdit) {
                    HStack(spacing: 8) {
                        Text(displayTag)
                            .font(AppFont.paperlogy3Light(size: 15))
                            .foregroundStyle(Color.kpPrimary)

                        Spacer(minLength: 0)

                        Image(systemName: "pencil.line")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.kpPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppSpacing.s)
                    .padding(.vertical, AppSpacing.xs)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)
            }

            if isEditingTag, let helperMessage {
                Text(helperMessage)
                    .font(AppFont.paperlogy4Regular(size: 12))
                    .foregroundStyle(helperColor ?? .red.opacity(0.95))
            }
        }
    }
}
