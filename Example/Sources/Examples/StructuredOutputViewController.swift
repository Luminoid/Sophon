//
//  StructuredOutputViewController.swift
//  SophonExample
//
//  One-call structured generation: prompt in, schema-constrained JSON out,
//  decoded straight into a Swift type.
//

import SophonGemini
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

    private static let schema = GeminiSchema.object(
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
        addFootnote("generateStructured sends the schema as responseSchema, retries transient failures per the retry policy, repairs truncated JSON, and decodes into TextAnalysis.")
    }

    // MARK: - Actions

    private func analyze() {
        generateTask?.cancel()
        analyzeButton.configuration?.showsActivityIndicator = true
        resultTextView.text = ""
        let prompt = "Analyze the following text.\n\n" + inputTextView.text
        generateTask = Task { [weak self] in
            do {
                let analysis = try await GeminiAPIClient.shared.generateStructured(
                    TextAnalysis.self,
                    label: "exampleAnalyze",
                    prompt: prompt,
                    schema: Self.schema
                )
                self?.resultTextView.text = """
                sentiment: \(analysis.sentiment)
                keywords: \(analysis.keywords.joined(separator: ", "))
                summary: \(analysis.summary)
                """
            } catch {
                self?.resultTextView.text = "Error: \(error.localizedDescription)"
            }
            self?.analyzeButton.configuration?.showsActivityIndicator = false
        }
    }
}
