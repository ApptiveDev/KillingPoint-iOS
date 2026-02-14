import SwiftUI

struct MyCollectionView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                Text("내 컬렉션")
                    .font(AppFont.paperlogy7Bold(size: 24))

                Text("저장한 킬링파트를 모아보는 공간입니다.")
                    .font(AppFont.paperlogy4Regular(size: 15))
                    .foregroundStyle(.secondary)

                ForEach(1...4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.primary200)
                        .frame(height: 110)
                        .overlay(alignment: .leading) {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Collection \(index)")
                                    .font(AppFont.paperlogy6SemiBold(size: 16))

                                Text("아티스트와 코멘트가 표시될 카드 영역")
                                    .font(AppFont.paperlogy4Regular(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(AppSpacing.m)
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, AppSpacing.l)
        }
    }
}
