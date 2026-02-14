import SwiftUI

struct AddTabView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(alignment: .leading, spacing: AppSpacing.l) {
                    Text("Add")
                        .font(AppFont.paperlogy7Bold(size: 28))
                        .foregroundStyle(.white)

                    Text("추가 탭입니다. 생성 플로우를 여기에 연결하세요.")
                        .font(AppFont.paperlogy4Regular(size: 16))
                        .foregroundStyle(.white.opacity(0.75))

                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 160)
                        .overlay {
                            Text("Create Content")
                                .font(AppFont.paperlogy6SemiBold(size: 16))
                                .foregroundStyle(.white)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppColors.primary600.opacity(0.4), lineWidth: 1)
                        }

                    Spacer()
                }
                .padding(AppSpacing.l)
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
