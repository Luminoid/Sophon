//
//  StructuredOutputViewController.swift
//  SophonExample
//
//  One-call structured generation through the cross-provider `LLMClient`:
//  prompt in, schema-constrained JSON out, decoded straight into a Swift type.
//  The schema is written once; each client encodes it in its provider's
//  dialect.
//

import SophonCore
import UIKit

private struct TextAnalysis: Decodable {
    let sentiment: String
    let keywords: [String]
    let summary: String
}

final class StructuredOutputViewController: ExamplePageViewController {
    // MARK: - Constants

    private static let sampleText = """
    The new observatory opened to record crowds this weekend. Visitors praised \
    the planetarium shows, though several noted the parking situation was \
    frustrating and the cafe ran out of food by noon.
    """

    private static let schema = LLMSchema.object(
        properties: [
            "sentiment": .string(description: "Overall sentiment of the text", enumValues: ["positive", "mixed", "negative"]),
            "keywords": .array(items: .string(), description: "Three to five key topics"),
            "summary": .string(description: "One-sentence summary"),
        ],
        required: ["sentiment", "keywords", "summary"],
        propertyOrdering: ["sentiment", "keywords", "summary"]
    )

    // MARK: - Properties

    private var generateTask: Task<Void, Never>?

    private lazy var inputTextView = makeInputTextView(text: Self.sampleText)
    private lazy var resultTextView = makeResultTextView()
    private lazy var analyzeButton = makeActionButton("Analyze") { [weak self] in self?.analyze() }

    // MARK: - Init

    deinit {
        generateTask?.cancel()
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        addSectionHeader("Input")
        stackView.addArrangedSubview(inputTextView)
        stackView.addArrangedSubview(analyzeButton)

        addSectionHeader("Decoded Result")
        stackView.addArrangedSubview(resultTextView)
        addFootnote(
            "generateStructured sends the LLMSchema in the provider's dialect (Gemini responseSchema, OpenAI strict json_schema or json_object, Anthropic output_config), "
                + "retries transient failures per the retry policy, repairs truncated JSON, and decodes into TextAnalysis. Pick the provider in Settings."
        )
    }

    // MARK: - Actions

    private func analyze() {
        generateTask?.cancel()
        analyzeButton.configuration?.showsActivityIndicator = true
        resultTextView.text = ""
        let prompt = "Analyze the following text.\n\n" + inputTextView.text
        let provider = ExampleProviders.selected
        // A cancelled task must not touch UI afterwards: a newer analyze owns
        // the result view and spinner by then.
        generateTask = Task { [weak self] in
            do {
                let analysis = try await provider.client.generateStructured(
                    TextAnalysis.self,
                    label: "exampleAnalyze",
                    prompt: prompt,
                    parts: [],
                    schema: Self.schema,
                    temperature: 0.1,
                    retryPolicy: nil
                )
                guard let self, !Task.isCancelled else { return }
                resultTextView.text = """
                provider: \(provider.title) (\(provider.client.currentModelID))
                sentiment: \(analysis.sentiment)
                keywords: \(analysis.keywords.joined(separator: ", "))
                summary: \(analysis.summary)
                """
                analyzeButton.configuration?.showsActivityIndicator = false
            } catch {
                guard let self, !Task.isCancelled else { return }
                resultTextView.text = "Error: \(error.localizedDescription)"
                analyzeButton.configuration?.showsActivityIndicator = false
            }
        }
    }
}
