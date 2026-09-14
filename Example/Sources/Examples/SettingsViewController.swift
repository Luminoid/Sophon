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
        config.buttonSize = .large
        let button = UIButton(configuration: config)
        button.showsMenuAsPrimaryAction = true
        button.accessibilityLabel = "Provider"
        button.accessibilityHint = "Opens a list of providers."
        return button
    }()

    private lazy var accessLabel = makeFootnoteLabel()

    private lazy var keyField: UITextField = {
        let field = UITextField()
        field.borderStyle = .roundedRect
        field.isSecureTextEntry = true
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        return field
    }()

    private lazy var deleteButton: UIButton = {
        let button = makeSecondaryButton("Delete") { [weak self] in self?.deleteKey() }
        button.role = .destructive
        return button
    }()

    /// Inline confirmation under the Save/Delete row; the Status section is off-screen on phones.
    private lazy var keyStatusLabel: UILabel = {
        let label = makeFootnoteLabel()
        label.isHidden = true
        return label
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
        config.buttonSize = .large
        let button = UIButton(configuration: config)
        button.showsMenuAsPrimaryAction = true
        button.accessibilityLabel = "Model"
        button.accessibilityHint = "Opens a list of models."
        return button
    }()

    private lazy var fetchButton = makeSecondaryButton("Fetch models from the API") { [weak self] in self?.fetchModels() }
    private lazy var listingLabel = makeFootnoteLabel()
    private lazy var listedModelsTextView = makeResultTextView()

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        return label
    }()

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
            deleteButton,
        ])
        buttonRow.spacing = 12
        buttonRow.distribution = .fillEqually
        stackView.addArrangedSubview(buttonRow)
        stackView.addArrangedSubview(keyStatusLabel)
        addFootnote("Stored in the Keychain under the account this app's configuration names, one per provider and region.")

        addSectionHeader("Feature Toggle")
        let toggleRow = UIStackView(arrangedSubviews: [toggleLabel, enabledSwitch])
        toggleRow.spacing = 12
        stackView.addArrangedSubview(toggleRow)
        addFootnote("isAvailable is true only when the toggle is on AND a key is stored.")

        addSectionHeader("Model")
        stackView.addArrangedSubview(modelButton)
        addFootnote("Presets come from the catalog's current models; Sophon picks the default. A stored model the app no longer offers resolves through the successor chain, then the fallback model.")
        stackView.addArrangedSubview(fetchButton)
        stackView.addArrangedSubview(listingLabel)
        stackView.addArrangedSubview(listedModelsTextView)

        addSectionHeader("Status")
        stackView.addArrangedSubview(statusLabel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // A second window or a returning user sees the current selection and key state.
        rebuildProviderMenu()
        refreshProvider()
    }

    // MARK: - Actions

    private func saveKey() {
        let key = (keyField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            showKeyStatus("Enter a key first.")
            return
        }
        do {
            try provider.configuration.saveAPIKey(key)
        } catch {
            showKeyStatus(error.localizedDescription)
            return
        }
        keyField.text = nil
        showKeyStatus("Key saved.")
        refreshStatus()
    }

    private func deleteKey() {
        provider.configuration.deleteAPIKey()
        keyField.text = nil
        showKeyStatus("Key removed.")
        refreshStatus()
    }

    private func promptForCustomModel() {
        let alert = UIAlertController(title: "Custom Model", message: "Enter a \(provider.title) model ID.", preferredStyle: .alert)
        alert.addTextField { [provider] in $0.placeholder = provider.client.currentModelID }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Use", style: .default) { [weak self, weak alert] _ in
            guard let self else { return }
            let id = (alert?.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty else { return }
            provider.selectCustomModel(id)
            rebuildModelMenu()
            refreshStatus()
        })
        present(alert, animated: true)
    }

    private func fetchModels() {
        listTask?.cancel()
        setBusy(true, on: fetchButton)
        listedModelsTextView.text = "Loading…"
        let selected = provider
        listTask = Task { [weak self] in
            do {
                let models = try await selected.listModels()
                guard let self, !Task.isCancelled else { return }
                listedModelsTextView.text = models.isEmpty ? "No models returned." : models.map(Self.describe).joined(separator: "\n")
                setBusy(false, on: fetchButton)
            } catch {
                guard let self, !Task.isCancelled else { return }
                listedModelsTextView.text = "Error: \(error.localizedDescription)"
                setBusy(false, on: fetchButton)
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
        providerButton.accessibilityValue = current
    }

    private func refreshProvider() {
        listTask?.cancel()
        setBusy(false, on: fetchButton)
        // A key typed for the previous provider must never be saved under this one.
        keyField.text = nil
        showKeyStatus(nil)
        keyField.placeholder = "\(provider.title) API key"
        toggleLabel.text = "\(provider.title) enabled"
        enabledSwitch.accessibilityLabel = toggleLabel.text
        enabledSwitch.isOn = provider.configuration.isEnabled
        listedModelsTextView.text = ""
        listingLabel.text = provider.listModelsNote
        accessLabel.text = Self.accessDescription(provider)
        rebuildModelMenu()
        refreshStatus()
    }

    private func rebuildModelMenu() {
        var actions = provider.modelOptions().map { option in
            UIAction(title: option.title, subtitle: option.subtitle, state: option.isSelected ? .on : .off) { [weak self] _ in
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
        modelButton.accessibilityValue = provider.currentModelName()
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

    private func showKeyStatus(_ text: String?) {
        keyStatusLabel.text = text
        keyStatusLabel.isHidden = text == nil
    }

    // MARK: - Helpers

    private static func accessDescription(_ provider: ExampleProviderDescriptor) -> String {
        let access = provider.freeAccess.note ?? "Paid from the first token."
        return provider.keyHint.isEmpty ? access : "\(access)\nGet a key at \(provider.keyHint)"
    }

    private static func describe(_ model: LLMRemoteModel) -> String {
        var line = model.id
        if let name = model.displayName, name != model.id { line += "  (\(name))" }
        switch (model.inputTokenLimit, model.outputTokenLimit) {
        case let (input?, output?): line += "  \(input) in / \(output) out"
        case let (input?, nil): line += "  \(input) in"
        case let (nil, output?): line += "  \(output) out"
        case (nil, nil): break
        }
        return line
    }
}
