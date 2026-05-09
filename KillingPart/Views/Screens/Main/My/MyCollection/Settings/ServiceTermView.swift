import SwiftUI

struct ServiceTermView: View {
    var body: some View {
        PolicyDocumentView(documentType: .serviceTerms)
            .preferredColorScheme(.dark)
    }
}
