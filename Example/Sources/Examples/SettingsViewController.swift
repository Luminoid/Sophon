//
//  SettingsViewController.swift
//  SophonExample
//
//  Provider selection, API key storage (SophonKeychain via the configuration),
//  feature toggle, model selection through the provider's model store, and a
//  live model listing.
//

import SophonCore
import UIKit

final class SettingsViewController: ExamplePageViewController {
    // MARK: - Properties

    private var provider: ExampleProviderDescriptor { ExampleProviders.selected }
    private var listTask: Task<Void, Never>?

    private lazy var providerButton: UIButton = {
        var config = UIButton.Configuration.gray()
        config.cornerStyle = .medium
        let button = UIButton(configuration: config)
        button.showsMenuAsPrimaryAction = true
        return button
    }()

    private lazy var accessLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        return label
    }()

    private lazy var keyField: UITextField = {
        let field = UITextField()
        field.borderStyle = .roundedRect
        field.isSecureTextEntry = true
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        return field
    }()

    private lazy var enabledSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            provider.configuration.setEnabled(enabledSwitch.isOn)
            refreshStatus()
        }, for: .valueChanged)
        return toggle
    }()

    private lazy var toggleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    private lazy var modelButton: UIButton = {
        var config = UIButton.Configuration.gray()
        config.cornerStyle = .medium
        let button = UIButton(configuration: config)
        button.showsMenuAsPrimaryAction = true
        return button
    }()

    private lazy var listedModelsTextView = makeResultTextView()

    // MARK: - Init

    deinit {
        listTask?.cancel()
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        addSectionHeader("Provider")
        stackView.addArrangedSubview(providerButton)
        stackView.addArrangedSubview(accessLabel)

        addSectionHeader("API Key")
        stackView.addArrangedSubview(keyField)
        let buttonRow = UIStackView(arrangedSubviews: [
            makeActionButton("Save") { [weak self] in self?.saveKey() },
            makeSecondaryButton("Delete") { [weak self] in self?.deleteKey() },
        ])
        buttonRow.spacing = 12
        buttonRow.distribution = .fillEqually
        stackView.addArrangedSubview(buttonRow)
        addFootnote("Stored in the Keychain under the account this app's configuration names, one per provider and region.")

        addSectionHeader("Feature Toggle")
        let toggleRow = UIStackView(arrangedSubviews: [toggleLabel, enabledSwitch])
        toggleRow.spacing = 12
        stackView.addArrangedSubview(toggleRow)
        addFootnote("isAvailable is true only when the toggle is on AND a key is stored.")

        addSectionHeader("Model")
        stackView.addArrangedSubview(modelButton)
        addFootnote("Presets come from the catalog's current models; Sophon picks the default. A stored model the app no longer offers resolves through the successor chain, then the fallback model.")
        stackView.addArrangedSubview(makeSecondaryButton("Fetch models from the API") { [weak self] in self?.fetchModels() })
        stackView.addArrangedSubview(listedModelsTextView)

        addSectionHeader("Status")
        stackView.addArrangedSubview(statusLabel)

        rebuildProviderMenu()
        refreshProvider()
    }

    // MARK: - Actions

    private func saveKey() {
        guard let key = keyField.text, !key.isEmpty else { return }
        do {
            try provider.configuration.saveAPIKey(key)
            keyField.text = nil
        } catch {
            statusLabel.text = error.localizedDescription
            return
        }
        refreshStatus()
    }

    private func deleteKey() {
        provider.configuration.deleteAPIKey()
        refreshStatus()
    }

    private func promptForCustomModel() {
        let alert = UIAlertController(title: "Custom Model", message: "Enter a \(provider.title) model ID.", preferredStyle: .alert)
        alert.addTextField { [provider] in $0.placeholder = provider.client.currentModelID }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Use", style: .default) { [weak self, weak alert] _ in
            guard let self, let id = alert?.textFields?.first?.text, !id.isEmpty else { return }
            provider.selectCustomModel(id)
            rebuildModelMenu()
            refreshStatus()
        })
        present(alert, animated: true)
    }

    private func fetchModels() {
        listTask?.cancel()
        listedModelsTextView.text = "Loading…"
        let client = provider.client
        listTask = Task { [weak self] in
            do {
                let models = try await client.listModels()
                guard let self, !Task.isCancelled else { return }
                listedModelsTextView.text = models.map { model in
                    var line = model.id
                    if let name = model.displayName, name != model.id { line += "  (\(name))" }
                    if let limit = model.inputTokenLimit { line += "  \(limit) in" }
                    return line
                }.joined(separator: "\n")
            } catch {
                guard let self, !Task.isCancelled else { return }
                listedModelsTextView.text = "Error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - UI Updates

    private func rebuildProviderMenu() {
        let current = provider.title
        let actions = ExampleProviders.all.map { descriptor in
            UIAction(title: descriptor.title, state: descriptor.title == current ? .on : .off) { [weak self] _ in
                ExampleProviders.selected = descriptor
                self?.rebuildProviderMenu()
                self?.refreshProvider()
            }
        }
        providerButton.menu = UIMenu(children: actions)
        providerButton.configuration?.title = current
    }

    private func refreshProvider() {
        listTask?.cancel()
        keyField.placeholder = "\(provider.title) API key"
        toggleLabel.text = "\(provider.title) enabled"
        enabledSwitch.isOn = provider.configuration.isEnabled
        listedModelsTextView.text = ""
        accessLabel.text = Self.accessDescription(provider)
        rebuildModelMenu()
        refreshStatus()
    }

    private func rebuildModelMenu() {
        var actions = provider.modelOptions().map { option in
            UIAction(title: option.title, state: option.isSelected ? .on : .off) { [weak self] _ in
                option.select()
                self?.rebuildModelMenu()
                self?.refreshStatus()
            }
        }
        actions.append(UIAction(title: "Custom…", state: provider.isCustomModelSelected() ? .on : .off) { [weak self] _ in
            self?.promptForCustomModel()
        })
        modelButton.menu = UIMenu(children: actions)
        modelButton.configuration?.title = provider.currentModelName()
    }

    private func refreshStatus() {
        let masked = provider.configuration.maskedAPIKeyDisplay ?? "none"
        let availability = provider.configuration.isAvailable ? "yes" : "no"
        statusLabel.text = """
        Key: \(masked)
        Model ID: \(provider.client.currentModelID)
        Available: \(availability)
        """
    }

    private static func accessDescription(_ provider: ExampleProviderDescriptor) -> String {
        let access = switch provider.freeAccess {
        case let .permanentTier(note): "Free tier: \(note)"
        case let .newUserQuota(note): "New-user quota: \(note)"
        case let .trialCredit(note): "Trial credit: \(note)"
        case .none: "Paid from the first token."
        }
        return provider.keyHint.isEmpty ? access : "\(access)\nGet a key at \(provider.keyHint)"
    }
}
