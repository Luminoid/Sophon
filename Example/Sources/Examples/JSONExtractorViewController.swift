//
//  JSONExtractorViewController.swift
//  SophonExample
//
//  SophonCore's LLMJSONExtractor, demonstrated offline: paste messy LLM
//  output, get a parseable JSON string back.
//

import SophonCore
import UIKit

final class JSONExtractorViewController: ExamplePageViewController {
    // MARK: - Constants

    /// A fenced response cut off mid-object, the way a MAX_TOKENS truncation
    /// actually arrives.
    private static let sampleText = """
    ```json
    {
      "name": "Sophon",
      "tags": ["swift", "gemini"],
      "nested": {"answer": 42
    """

    // MARK: - Properties

    private lazy var inputTextView = makeInputTextView(text: Self.sampleText)
    private lazy var resultTextView = makeResultTextView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        addSectionHeader("LLM Output")
        stackView.addArrangedSubview(inputTextView)
        stackView.addArrangedSubview(makeActionButton("Extract") { [weak self] in self?.extract() })

        addSectionHeader("Extracted JSON")
        stackView.addArrangedSubview(resultTextView)
        addFootnote(
            "Two steps, mirroring the client's decode path: extractJSON strips fences and isolates the outermost balanced braces; "
                + "if the result still fails to parse, repairTruncatedJSON closes dangling strings, arrays, and objects. No API key needed."
        )
    }

    // MARK: - Actions

    private func extract() {
        var json = LLMJSONExtractor.extractJSON(from: inputTextView.text)
        var repairApplied = false
        if !parses(json), let repaired = LLMJSONExtractor.repairTruncatedJSON(json) {
            json = repaired
            repairApplied = true
        }
        resultTextView.text = json + "\n\nTruncation repair applied: \(repairApplied ? "yes" : "no")\nParses as JSON: \(parses(json) ? "yes" : "no")"
    }

    // MARK: - Helpers

    private func parses(_ string: String) -> Bool {
        (try? JSONSerialization.jsonObject(with: Data(string.utf8))) != nil
    }
}
