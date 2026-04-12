import SwiftUI

struct MyCollectionStoreKillingPartSectionView: View {
    let diaries: [StoredDiaryFeedModel]
    let isLoadingInitial: Bool
    let isLoadingMore: Bool
    let errorMessage: String?
    let onDiaryAppear: (StoredDiaryFeedModel) -> Void
    let onBottomTriggerAppear: () -> Void

    var body: some View {
        Group {
            if isLoadingInitial && diaries.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.white.opacity(0.88))
                    Spacer()
                }
                .padding(.top, AppSpacing.xl)
            } else if diaries.isEmpty {
                emptyStoredDiaryPlaceholder
            } else {
                LazyVGrid(columns: feedGridColumns, spacing: AppSpacing.s) {
                    ForEach(diaries) { diary in
                        MyCollectionStoreKillingPartCard(diary: diary)
                            .onAppear {
                                onDiaryAppear(diary)
                            }
                    }
                }

                Color.clear
                    .frame(height: 1)
                    .id("my-collection-stores-bottom-trigger-\(diaries.count)")
                    .onAppear {
                        onBottomTriggerAppear()
                    }
            }
        }

        if isLoadingMore {
            HStack {
                Spacer()
                ProgressView()
                    .tint(.white.opacity(0.88))
                Spacer()
            }
            .padding(.top, AppSpacing.s)
        }

        if let errorMessage {
            Text(errorMessage)
                .font(AppFont.paperlogy4Regular(size: 13))
                .foregroundStyle(.red.opacity(0.95))
        }
    }

    private var feedGridColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: AppSpacing.s),
            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: AppSpacing.s)
        ]
    }

    private var emptyStoredDiaryPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.08))
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .overlay {
                Text("아직 보관한 킬링파트가 없어요.")
                    .font(AppFont.paperlogy5Medium(size: 14))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
    }
}
