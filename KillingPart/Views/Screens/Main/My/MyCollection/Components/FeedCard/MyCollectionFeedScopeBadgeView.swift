import SwiftUI

struct MyCollectionFeedScopeBadgeView: View {
    let scope: DiaryScope

    var body: some View {
        Image(systemName: scopeIconName(scope))
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(6)
    }

    private func scopeIconName(_ scope: DiaryScope) -> String {
        switch scope {
        case .private:
            return "lock.fill"
        case .public:
            return "globe"
        case .killingPart:
            return "music.note"
        }
    }
}
