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

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Self.contentPadding),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: Self.contentPadding),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -Self.contentPadding),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Self.contentPadding),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -2 * Self.contentPadding),
        ])
    }

    // MARK: - Section Helpers

    func addSectionHeader(_ text: String) {
        let label = UILabel()
        label.text = text.uppercased()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        if !stackView.arrangedSubviews.isEmpty {
            stackView.setCustomSpacing(24, after: stackView.arrangedSubviews[stackView.arrangedSubviews.count - 1])
        }
        stackView.addArrangedSubview(label)
    }

    func addFootnote(_ text: String) {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        stackView.addArrangedSubview(label)
    }

    // MARK: - Control Factories

    func makeActionButton(_ title: String, action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.cornerStyle = .medium
        return UIButton(configuration: config, primaryAction: UIAction { _ in action() })
    }

    func makeSecondaryButton(_ title: String, action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.gray()
        config.title = title
        config.cornerStyle = .medium
        return UIButton(configuration: config, primaryAction: UIAction { _ in action() })
    }

    func makeInputTextView(text: String) -> UITextView {
        let textView = UITextView()
        textView.text = text
        textView.font = .preferredFont(forTextStyle: .body)
        textView.layer.borderColor = UIColor.separator.cgColor
        textView.layer.borderWidth = 1
        textView.layer.cornerRadius = 8
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.heightAnchor.constraint(equalToConstant: 140).isActive = true
        return textView
    }

    func makeResultTextView() -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .footnote).pointSize, weight: .regular)
        textView.backgroundColor = .secondarySystemBackground
        textView.layer.cornerRadius = 8
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.heightAnchor.constraint(equalToConstant: 220).isActive = true
        return textView
    }
}
