//
//  SettingsViewController.swift
//  SophonExample
//
//  API key storage (SophonKeychain via the configuration), feature toggle,
//  and model selection through GeminiModelStore.
//

import SophonGemini
import UIKit

final class SettingsViewController: ExamplePageViewController {
    // MARK: - Properties

    private let configuration = GeminiClientConfiguration.example
    private var modelStore: GeminiModelStore { GeminiAPIClient.shared.modelStore }

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        return label
    }()

    private lazy var keyField: UITextField = {
        let field = UITextField()
        field.placeholder = "Gemini API key"
        field.borderStyle = .roundedRect
        field.isSecureTextEntry = true
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        return field
    }()

    private lazy var enabledSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.isOn = configuration.isEnabled
        toggle.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            configuration.setEnabled(enabledSwitch.isOn)
            refreshStatus()
        }, for: .valueChanged)
        return toggle
    }()

    private lazy var modelButton: UIButton = {
        var config = UIButton.Configuration.gray()
        config.cornerStyle = .medium
        let button = UIButton(configuration: config)
        button.showsMenuAsPrimaryAction = true
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        addSectionHeader("API Key")
        stackView.addArrangedSubview(keyField)
        let buttonRow = UIStackView(arrangedSubviews: [
            makeActionButton("Save") { [weak self] in self?.saveKey() },
            makeSecondaryButton("Delete") { [weak self] in self?.deleteKey() },
        ])
        buttonRow.spacing = 12
        buttonRow.distribution = .fillEqually
        stackView.addArrangedSubview(buttonRow)
        addFootnote("Stored in the Keychain under the account this app's configuration names. Get a key at aistudio.google.com.")

        addSectionHeader("Feature Toggle")
        let toggleRow = UIStackView(arrangedSubviews: [makeToggleLabel(), enabledSwitch])
        toggleRow.spacing = 12
        stackView.addArrangedSubview(toggleRow)
        addFootnote("isGeminiAvailable is true only when the toggle is on AND a key is stored.")

        addSectionHeader("Model")
        stackView.addArrangedSubview(modelButton)
        addFootnote("Selection persists via GeminiModelStore. A stored model the app no longer offers resolves through the successor chain, then the fallback model.")

        addSectionHeader("Status")
        stackView.addArrangedSubview(statusLabel)

        rebuildModelMenu()
        refreshStatus()
    }

    // MARK: - Actions

    private func saveKey() {
        guard let key = keyField.text, !key.isEmpty else { return }
        do {
            try configuration.saveAPIKey(key)
            keyField.text = nil
        } catch {
            statusLabel.text = error.localizedDescription
            return
        }
        refreshStatus()
    }

    private func deleteKey() {
        configuration.deleteAPIKey()
        refreshStatus()
    }

    private func promptForCustomModel() {
        let alert = UIAlertController(title: "Custom Model", message: "Enter a Gemini model ID.", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "gemini-3.5-flash" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Use", style: .default) { [weak self, weak alert] _ in
            guard let self, let id = alert?.textFields?.first?.text, !id.isEmpty else { return }
            modelStore.select(.custom(id))
            rebuildModelMenu()
            refreshStatus()
        })
        present(alert, animated: true)
    }

    // MARK: - UI Updates

    private func rebuildModelMenu() {
        let current = modelStore.current
        var actions = configuration.availableModels.map { model in
            UIAction(title: model.displayName, state: model == current ? .on : .off) { [weak self] _ in
                guard let self else { return }
                modelStore.select(model)
                rebuildModelMenu()
                refreshStatus()
            }
        }
        var isCustom = false
        if case .custom = current { isCustom = true }
        actions.append(UIAction(title: "Custom…", state: isCustom ? .on : .off) { [weak self] _ in
            self?.promptForCustomModel()
        })
        modelButton.menu = UIMenu(children: actions)
        modelButton.configuration?.title = current.displayName
    }

    private func refreshStatus() {
        let masked = configuration.maskedAPIKeyDisplay ?? "none"
        let availability = configuration.isGeminiAvailable ? "yes" : "no"
        statusLabel.text = """
        Key: \(masked)
        Model ID: \(modelStore.current.modelID)
        Available: \(availability)
        """
    }

    // MARK: - Helpers

    private func makeToggleLabel() -> UILabel {
        let label = UILabel()
        label.text = "Gemini enabled"
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        return label
    }
}
