import SwiftUI
import UIKit

struct AddSearchFieldView: View {
    @Binding var query: String
    let hasQuery: Bool
    let dismissKeyboardSignal: Int
    let onSubmit: () -> Void
    let onQueryChanged: () -> Void
    let onClear: () -> Void

    var body: some View {
        NativeSearchField(
            text: $query,
            placeholder: "곡 또는 아티스트 검색",
            dismissKeyboardSignal: dismissKeyboardSignal,
            onSubmit: onSubmit,
            onQueryChanged: onQueryChanged,
            onClear: onClear
        )
        .frame(height: 52)
        .padding(.horizontal, 2)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(hasQuery ? AppColors.primary600.opacity(0.6) : Color.white.opacity(0.25), lineWidth: 1)
        }
    }
}

private struct NativeSearchField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let dismissKeyboardSignal: Int
    let onSubmit: () -> Void
    let onQueryChanged: () -> Void
    let onClear: () -> Void

    func makeUIView(context: Context) -> UISearchTextField {
        let textField = UISearchTextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.placeholder = placeholder
        textField.returnKeyType = .search
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.clearButtonMode = .whileEditing
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.textColor = .white
        textField.tintColor = .white
        textField.font = UIFont.preferredFont(forTextStyle: .body)
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.65)]
        )
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)

        if let iconView = textField.leftView as? UIImageView {
            iconView.tintColor = UIColor.white.withAlphaComponent(0.8)
        }

        return textField
    }

    func updateUIView(_ uiView: UISearchTextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        if context.coordinator.lastDismissKeyboardSignal != dismissKeyboardSignal {
            context.coordinator.lastDismissKeyboardSignal = dismissKeyboardSignal
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            dismissKeyboardSignal: dismissKeyboardSignal,
            onSubmit: onSubmit,
            onQueryChanged: onQueryChanged,
            onClear: onClear
        )
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding private var text: String
        var lastDismissKeyboardSignal: Int
        private let onSubmit: () -> Void
        private let onQueryChanged: () -> Void
        private let onClear: () -> Void

        init(
            text: Binding<String>,
            dismissKeyboardSignal: Int,
            onSubmit: @escaping () -> Void,
            onQueryChanged: @escaping () -> Void,
            onClear: @escaping () -> Void
        ) {
            _text = text
            self.lastDismissKeyboardSignal = dismissKeyboardSignal
            self.onSubmit = onSubmit
            self.onQueryChanged = onQueryChanged
            self.onClear = onClear
        }

        @objc
        func textDidChange(_ sender: UISearchTextField) {
            let newText = sender.text ?? ""
            if text != newText {
                text = newText
            }
            onQueryChanged()
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            onSubmit()
            textField.resignFirstResponder()
            return true
        }

        func textFieldShouldClear(_ textField: UITextField) -> Bool {
            onClear()
            return true
        }
    }
}
