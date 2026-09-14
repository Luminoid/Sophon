//
//  ExamplePageViewController.swift
//  SophonExample
//
//  Base class for example pages: a vertical stack inside a scroll view, plus
//  small factories for the controls the demo pages share.
//

import UIKit

// Subclassed by the demo pages (SwiftFormat's per-file preferFinalClasses can't see them).
// swiftformat:disable:next preferFinalClasses
class ExamplePageViewController: UIViewController {
    // MARK: - Constants

    private static let contentPadding: CGFloat = 16
    /// Readable line length on iPad; phones never reach it.
    private static let maxContentWidth: CGFloat = 700
    private static let inputHeight: CGFloat = 140
    private static let resultHeight: CGFloat = 220

    // MARK: - Properties

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.keyboardDismissMode = .onDrag
        scrollView.alwaysBounceVertical = true
        return scrollView
    }()

    let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        return stackView
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        // The guide sits at the view's bottom edge while the keyboard is hidden, so
        // the scroll view still runs under the home indicator (the content inset
        // adjustment keeps the content clear of it) and rises with the keyboard.
        view.keyboardLayoutGuide.usesBottomSafeArea = false

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        // Fill the frame width on phones; on iPad the required cap wins and the
        // inequalities keep the content guide at least as wide as the stack plus padding.
        let fillWidth = stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -2 * Self.contentPadding)
        fillWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Self.contentPadding),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Self.contentPadding),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: scrollView.contentLayoutGuide.leadingAnchor, constant: Self.contentPadding),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -Self.contentPadding),
            stackView.centerXAnchor.constraint(equalTo: scrollView.contentLayoutGuide.centerXAnchor),
            stackView.widthAnchor.constraint(lessThanOrEqualToConstant: Self.maxContentWidth),
            fillWidth,
        ])
    }

    // MARK: - Section Helpers

    func addSectionHeader(_ text: String) {
        if let last = stackView.arrangedSubviews.last {
            stackView.setCustomSpacing(24, after: last)
        }
        stackView.addArrangedSubview(makeFootnoteLabel(text))
    }

    func addFootnote(_ text: String) {
        stackView.addArrangedSubview(makeFootnoteLabel(text))
    }

    func makeFootnoteLabel(_ text: String? = nil) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }

    // MARK: - Control Factories

    func makeActionButton(_ title: String, action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.cornerStyle = .medium
        config.buttonSize = .large
        return UIButton(configuration: config, primaryAction: UIAction { _ in action() })
    }

    func makeSecondaryButton(_ title: String, action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.gray()
        config.title = title
        config.cornerStyle = .medium
        config.buttonSize = .large
        return UIButton(configuration: config, primaryAction: UIAction { _ in action() })
    }

    func makeInputTextView(text: String) -> UITextView {
        let textView = UITextView()
        textView.text = text
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.layer.borderColor = UIColor.separator.resolvedColor(with: textView.traitCollection).cgColor
        textView.layer.borderWidth = 1
        textView.layer.cornerRadius = 8
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.heightAnchor.constraint(equalToConstant: UIFontMetrics.default.scaledValue(for: Self.inputHeight)).isActive = true
        // A CGColor never adapts on its own; re-resolve it when light and dark flip.
        _ = textView.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (textView: UITextView, _: UITraitCollection) in
            textView.layer.borderColor = UIColor.separator.resolvedColor(with: textView.traitCollection).cgColor
        }
        return textView
    }

    func makeResultTextView() -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .monospacedSystemFont(ofSize: 13, weight: .regular))
        textView.adjustsFontForContentSizeCategory = true
        textView.backgroundColor = .secondarySystemBackground
        textView.layer.cornerRadius = 8
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.heightAnchor.constraint(equalToConstant: UIFontMetrics.default.scaledValue(for: Self.resultHeight)).isActive = true
        return textView
    }

    // MARK: - Helpers

    /// Spinner and enabled state move together, so a page never shows a spinner on a tappable button.
    func setBusy(_ busy: Bool, on button: UIButton) {
        button.configuration?.showsActivityIndicator = busy
        button.isEnabled = !busy
    }
}
