//
//  ExampleViewController.swift
//  SophonExample
//
//  Catalog list that navigates to a page per demonstrated capability.
//

import UIKit

// MARK: - Catalog Data

private struct ExampleItem {
    let title: String
    let subtitle: String
    let iconName: String
    let makeViewController: @MainActor () -> UIViewController
}

private struct ExampleSection {
    let title: String
    let items: [ExampleItem]
}

private let exampleSections: [ExampleSection] = [
    // Key + model selection first: the Gemini demos need a stored API key.
    ExampleSection(title: "Setup", items: [
        ExampleItem(
            title: "Settings",
            subtitle: "API key, feature toggle, model selection",
            iconName: "gearshape",
            makeViewController: { SettingsViewController() }
        ),
    ]),
    ExampleSection(title: "Gemini", items: [
        ExampleItem(
            title: "Structured Output",
            subtitle: "Schema-constrained JSON with generateStructured",
            iconName: "curlybraces",
            makeViewController: { StructuredOutputViewController() }
        ),
        ExampleItem(
            title: "Chat",
            subtitle: "Multi-turn conversation with generateText",
            iconName: "bubble.left.and.bubble.right",
            makeViewController: { ChatViewController() }
        ),
    ]),
    ExampleSection(title: "Core", items: [
        ExampleItem(
            title: "JSON Extractor",
            subtitle: "Fence stripping, brace extraction, truncation repair (offline)",
            iconName: "wand.and.sparkles",
            makeViewController: { JSONExtractorViewController() }
        ),
    ]),
]

// MARK: - About Section

private struct InfoItem {
    let title: String
    let detail: String
    let iconName: String
    let isLink: Bool

    init(_ title: String, detail: String, iconName: String, isLink: Bool = false) {
        self.title = title
        self.detail = detail
        self.iconName = iconName
        self.isLink = isLink
    }
}

private let aboutItems: [InfoItem] = [
    InfoItem("Version", detail: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—", iconName: "tag"),
    InfoItem("GitHub", detail: "Luminoid/Sophon", iconName: "link", isLink: true),
    InfoItem("Platform", detail: "iOS 18+ · Mac Catalyst 18+ · macOS 15+", iconName: "iphone"),
    InfoItem("Swift", detail: "6.2 · Zero dependencies", iconName: "swift"),
    InfoItem("License", detail: "MIT", iconName: "doc.text"),
]

// MARK: - ExampleViewController

final class ExampleViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    // MARK: - Constants

    // swiftlint:disable:next force_unwrapping
    private static let githubURL = URL(string: "https://github.com/Luminoid/Sophon")!
    private static let aboutSectionIndex = exampleSections.count

    // MARK: - Properties

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        return tableView
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sophon"
        view.backgroundColor = .systemGroupedBackground

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Data Source

    func numberOfSections(in tableView: UITableView) -> Int {
        exampleSections.count + 1 // +1 for About
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == Self.aboutSectionIndex { return "About" }
        return exampleSections[section].title
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == Self.aboutSectionIndex { return aboutItems.count }
        return exampleSections[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

        if indexPath.section == Self.aboutSectionIndex {
            let info = aboutItems[indexPath.row]
            var config = cell.defaultContentConfiguration()
            config.text = info.title
            config.secondaryText = info.detail
            config.secondaryTextProperties.color = info.isLink ? .tintColor : .secondaryLabel
            config.image = UIImage(systemName: info.iconName)
            cell.contentConfiguration = config
            cell.accessoryType = info.isLink ? .disclosureIndicator : .none
            cell.selectionStyle = info.isLink ? .default : .none
            return cell
        }

        let item = exampleSections[indexPath.section].items[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = item.title
        config.secondaryText = item.subtitle
        config.image = UIImage(systemName: item.iconName)
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default
        return cell
    }

    // MARK: - Delegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == Self.aboutSectionIndex {
            guard aboutItems[indexPath.row].isLink else { return }
            UIApplication.shared.open(Self.githubURL)
            return
        }

        let item = exampleSections[indexPath.section].items[indexPath.row]
        let detail = item.makeViewController()
        detail.title = item.title
        navigationController?.pushViewController(detail, animated: true)
    }
}
