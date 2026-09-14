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

    private lazy var transcriptTextView = makeResultTextView()

    private lazy var messageField: UITextField = {
        let field = UITextField()
        field.placeholder = "Message"
        field.borderStyle = .roundedRect
        field.text = "In one sentence, who are you?"
        return field
    }()

    private lazy var sendButton = makeActionButton("Send") { [weak self] in self?.send() }

    // MARK: - Init

    deinit {
        sendTask?.cancel()
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

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

    // MARK: - Actions

    private func send() {
        let message = (messageField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        sendTask?.cancel()
        sendButton.configuration?.showsActivityIndicator = true
        messageField.text = nil
        contents.append(LLMMessage(parts: [.text(message)], role: .user))
        appendTranscript("You: \(message)")
        // Capture the history by value, and hold self weakly across the await so
        // a popped screen deallocates (deinit cancels) instead of riding out the
        // request. A cancelled task must not touch state afterwards: Reset or a
        // newer send owns the transcript and spinner by then.
        let history = contents
        let provider = ExampleProviders.selected
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
                sendButton.configuration?.showsActivityIndicator = false
            } catch {
                guard let self, !Task.isCancelled else { return }
                // Drop the failed turn so a retry does not double-send it.
                if !contents.isEmpty { contents.removeLast() }
                appendTranscript("Error: \(error.localizedDescription)")
                sendButton.configuration?.showsActivityIndicator = false
            }
        }
    }

    private func reset() {
        sendTask?.cancel()
        sendButton.configuration?.showsActivityIndicator = false
        contents = []
        transcriptTextView.text = ""
    }

    // MARK: - UI Updates

    private func appendTranscript(_ line: String) {
        let existing = transcriptTextView.text ?? ""
        transcriptTextView.text = existing.isEmpty ? line : existing + "\n\n" + line
        let bottom = NSRange(location: (transcriptTextView.text as NSString).length, length: 0)
        transcriptTextView.scrollRangeToVisible(bottom)
    }
}
