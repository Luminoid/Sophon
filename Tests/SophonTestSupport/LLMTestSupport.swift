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
    private static let lock = NSLock()
    private nonisolated(unsafe) static var suiteNames: [String] = []
    private nonisolated(unsafe) static var cleanupRegistered = false

    /// A fresh, isolated UserDefaults suite so parallel tests never interfere.
    /// Every suite created this way is removed from disk when the test process
    /// exits, so runs don't leave `SophonTests.<UUID>` plists behind.
    public static func makeDefaults() -> UserDefaults {
        let name = "SophonTests." + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: name) else {
            preconditionFailure("Could not create UserDefaults suite \(name)")
        }
        defaults.removePersistentDomain(forName: name)
        lock.withLock {
            suiteNames.append(name)
            if !cleanupRegistered {
                cleanupRegistered = true
                atexit { Self.removeAllSuites() }
            }
        }
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

    private static func removeAllSuites() {
        let names = lock.withLock { suiteNames }
        for name in names {
            UserDefaults(suiteName: name)?.removePersistentDomain(forName: name)
            UserDefaults.standard.removeSuite(named: name)
        }
    }
}
