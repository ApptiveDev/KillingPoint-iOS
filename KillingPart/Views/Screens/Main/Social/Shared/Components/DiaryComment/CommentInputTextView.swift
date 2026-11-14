import SwiftUI
import UIKit

/// 멘션을 입력창 안에서 강조해야 해서 TextField 대신 UITextView 사용 (시안: 입력 중 @멘션 초록색)
struct CommentInputTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    @Binding var requestedCursor: Int?
    let highlightRanges: [NSRange]
    let maxLength: Int
    let onCursorChange: (Int) -> Void

    private static let font = UIFont(name: "Paperlogy-4Regular", size: 15) ?? .systemFont(ofSize: 15)
    private static let maxLines: CGFloat = 4
    private static let baseAttributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: UIColor.white
    ]

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.typingAttributes = Self.baseAttributes
        textView.tintColor = UIColor(AppColors.primary600)
        textView.keyboardAppearance = .dark
        textView.isScrollEnabled = false
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self

        if textView.text != text {
            textView.text = text
        }
        // 한글 조합 중(markedText)에 속성을 바꾸면 입력이 깨지므로 건너뛴다
        if textView.markedTextRange == nil {
            applyHighlights(to: textView)
        }
        if let cursor = requestedCursor {
            let location = min(cursor, textView.text.utf16.count)
            textView.selectedRange = NSRange(location: location, length: 0)
            DispatchQueue.main.async { requestedCursor = nil }
        }

        if isFocused, !textView.isFirstResponder {
            DispatchQueue.main.async { textView.becomeFirstResponder() }
        } else if !isFocused, textView.isFirstResponder {
            DispatchQueue.main.async { textView.resignFirstResponder() }
        }
    }

    /// 1~4줄까지 늘어나고 그 이상은 내부 스크롤
    func sizeThatFits(_ proposal: ProposedViewSize, uiView textView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? textView.bounds.width
        guard width > 0 else { return nil }
        let fitting = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let maxHeight = ceil(Self.font.lineHeight * Self.maxLines)
        let isOverflowing = fitting.height > maxHeight
        if textView.isScrollEnabled != isOverflowing {
            DispatchQueue.main.async { textView.isScrollEnabled = isOverflowing }
        }
        return CGSize(width: width, height: max(min(fitting.height, maxHeight), ceil(Self.font.lineHeight)))
    }

    private func applyHighlights(to textView: UITextView) {
        let storage = textView.textStorage
        let fullRange = NSRange(location: 0, length: storage.length)
        let selected = textView.selectedRange
        storage.beginEditing()
        storage.setAttributes(Self.baseAttributes, range: fullRange)
        for range in highlightRanges where NSMaxRange(range) <= storage.length {
            storage.addAttribute(.foregroundColor, value: UIColor(AppColors.primary600), range: range)
        }
        storage.endEditing()
        textView.selectedRange = selected
        // 멘션 바로 뒤에 이어 쓰는 글자가 초록색이 되지 않도록
        textView.typingAttributes = Self.baseAttributes
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: CommentInputTextView

        init(parent: CommentInputTextView) {
            self.parent = parent
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // 조합 중인 한글은 확정 전 길이가 들쭉날쭉해서 제한하지 않는다
            guard textView.markedTextRange == nil else { return true }
            let current = textView.text ?? ""
            guard let swiftRange = Range(range, in: current) else { return true }
            return current.replacingCharacters(in: swiftRange, with: text).count <= parent.maxLength
        }

        func textViewDidChange(_ textView: UITextView) {
            var newText = textView.text ?? ""
            if textView.markedTextRange == nil, newText.count > parent.maxLength {
                newText = String(newText.prefix(parent.maxLength))
                textView.text = newText
            }
            parent.text = newText
            parent.onCursorChange(textView.selectedRange.location)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard textView.markedTextRange == nil else { return }
            parent.onCursorChange(textView.selectedRange.location)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if !parent.isFocused { parent.isFocused = true }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if parent.isFocused { parent.isFocused = false }
        }
    }
}
