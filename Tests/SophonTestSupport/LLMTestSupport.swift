//
//  LLMTestSupport.swift
//  SophonTestSupport
//
//  Shared factories for the provider test targets: isolated UserDefaults
//  suites and canned HTTP responses that never touch the real Keychain or
//  standard defaults.
//

import Foundation

public enum LLMTestSupport {
    /// A fresh, isolated UserDefaults suite so parallel tests never interfere.
    public static func makeDefaults() -> UserDefaults {
        let name = "SophonTests." + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: name) else {
            preconditionFailure("Could not create UserDefaults suite \(name)")
        }
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    public static func makeHTTPResponse(status: Int, headers: [String: String]? = nil) -> HTTPURLResponse {
        guard let url = URL(string: "https://example.com"),
              let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers) else {
            preconditionFailure("Could not build HTTPURLResponse")
        }
        return response
    }

    /// Decodes a request body (or any JSON data) into a dictionary.
    public static func jsonObject(_ data: Data?) -> [String: Any]? {
        guard let data else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
