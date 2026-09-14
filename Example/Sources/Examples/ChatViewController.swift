//
//  ChatViewController.swift
//  SophonExample
//
//  Multi-turn plain-text conversation through the cross-provider `LLMClient`:
//  role-tagged LLMMessage history in, model reply out via generateText.
//

import SophonCore
import UIKit

final class ChatViewController: ExamplePageViewController {
    // MARK: - Properties

    private var contents: [LLMMessage] = []
    private var sendTask: Task<Void, Never>?
    /// True from send() until its task lands a reply or an error. A cancelled
    /// task never clears it: the newer send owns the state by then.
    private var isSending = false

    private lazy var providerLabel = makeFootnoteLabel()
    private lazy var transcriptTextView = makeResultTextView()

    private lazy var messageField: UITextField = {
        let field = UITextField()
        field.placeholder = "Message"
        field.borderStyle = .roundedRect
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.returnKeyType = .send
        field.text = "In one sentence, who are you?"
        field.addAction(UIAction { [weak self] _ in self?.send() }, for: .editingDidEndOnExit)
        return field
    }()

    private lazy var sendButton = makeActionButton("Send") { [weak self] in self?.send() }

    /// Lets Command-Return reach the page before the message field is focused.
    override var canBecomeFirstResponder: Bool { true }

    override var keyCommands: [UIKeyCommand]? {
        let send = UIKeyCommand(input: "\r", modifierFlags: .command, action: #selector(sendFromKeyboard))
        send.discoverabilityTitle = "Send"
        return [send]
    }

    // MARK: - Init

    deinit {
        sendTask?.cancel()
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        stackView.addArrangedSubview(providerLabel)

        addSectionHeader("Transcript")
        stackView.addArrangedSubview(transcriptTextView)

        addSectionHeader("Message")
        stackView.addArrangedSubview(messageField)
        let buttonRow = UIStackView(arrangedSubviews: [
            sendButton,
            makeSecondaryButton("Reset") { [weak self] in self?.reset() },
        ])
        buttonRow.spacing = 12
        buttonRow.distribution = .fillEqually
        stackView.addArrangedSubview(buttonRow)
        addFootnote("Each turn appends a role-tagged LLMMessage (user or assistant) and resends the whole history, so the model sees the full conversation. Pick the provider in Settings.")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let provider = ExampleProviders.selected
        providerLabel.text = "\(provider.title) · \(provider.client.currentModelID)"
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    // MARK: - Actions

    private func send() {
        let message = (messageField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        let provider = ExampleProviders.selected
        guard provider.configuration.isAvailable else {
            appendTranscript("Enable \(provider.title) in Settings and add an API key.")
            return
        }
        if isSending {
            // The in-flight turn's reply is never coming; drop the turn so the
            // history keeps alternating user and assistant.
            sendTask?.cancel()
            if !contents.isEmpty { contents.removeLast() }
            appendTranscript("(Previous message cancelled and dropped from the history.)")
        }
        isSending = true
        setBusy(true, on: sendButton)
        messageField.text = nil
        contents.append(LLMMessage(parts: [.text(message)], role: .user))
        appendTranscript("You: \(message)")
        // Capture the history by value, and hold self weakly across the await so
        // a popped screen deallocates (deinit cancels) instead of riding out the
        // request. A cancelled task must not touch state afterwards: Reset or a
        // newer send owns the transcript and button by then.
        let history = contents
        sendTask = Task { [weak self] in
            do {
                let reply = try await provider.client.generateText(
                    label: "exampleChat",
                    contents: history,
                    temperature: 0.3,
                    retryPolicy: nil
                )
                guard let self, !Task.isCancelled else { return }
                contents.append(LLMMessage(parts: [.text(reply)], role: .assistant))
                appendTranscript("\(provider.title): \(reply)")
                finishSend()
            } catch {
                guard let self, !Task.isCancelled else { return }
                // Drop the failed turn so a retry does not double-send it.
                if !contents.isEmpty { contents.removeLast() }
                appendTranscript("Error (turn discarded): \(error.localizedDescription)")
                finishSend()
            }
        }
    }

    @objc private func sendFromKeyboard() {
        send()
    }

    private func reset() {
        sendTask?.cancel()
        finishSend()
        contents = []
        transcriptTextView.text = ""
    }

    // MARK: - UI Updates

    private func finishSend() {
        isSending = false
        setBusy(false, on: sendButton)
    }

    private func appendTranscript(_ line: String) {
        let existing = transcriptTextView.text ?? ""
        transcriptTextView.text = existing.isEmpty ? line : existing + "\n\n" + line
        let bottom = NSRange(location: (transcriptTextView.text as NSString).length, length: 0)
        transcriptTextView.scrollRangeToVisible(bottom)
    }
}
