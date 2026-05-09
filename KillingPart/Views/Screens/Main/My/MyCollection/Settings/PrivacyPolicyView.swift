import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        PolicyDocumentView(documentType: .privacy)
            .preferredColorScheme(.dark)
    }
}
