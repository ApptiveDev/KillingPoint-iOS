import SwiftUI

struct AddTabView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                Text("Add")
                    .font(AppFont.paperlogy7Bold(size: 28))

                Text("추가 탭입니다. 생성 플로우를 여기에 연결하세요.")
                    .font(AppFont.paperlogy4Regular(size: 16))
                    .foregroundStyle(.secondary)

                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.primary300)
                    .frame(height: 160)
                    .overlay {
                        Text("Create Content")
                            .font(AppFont.paperlogy6SemiBold(size: 16))
                    }

                Spacer()
            }
            .padding(AppSpacing.l)
            .navigationTitle("추가")
        }
    }
}
