import SwiftUI
import UIKit

struct ScrollViewIntrospector: UIViewRepresentable {
    let onFind: (UIScrollView) -> Void

    func makeUIView(context: Context) -> UIView {
        FinderView(onFind: onFind)
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    final class FinderView: UIView {
        private let onFind: (UIScrollView) -> Void
        private var didSend = false

        init(onFind: @escaping (UIScrollView) -> Void) {
            self.onFind = onFind
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            backgroundColor = .clear
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard !didSend else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self, !self.didSend else { return }
                if let sv = self.findEnclosingScrollView() {
                    self.didSend = true
                    self.onFind(sv)
                }
            }
        }

        private func findEnclosingScrollView() -> UIScrollView? {
            var v: UIView? = self
            while let s = v?.superview {
                if let sv = s as? UIScrollView { return sv }
                v = s
            }
            return nil
        }
    }
}
