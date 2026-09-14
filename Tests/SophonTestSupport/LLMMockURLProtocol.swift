//
//  LLMMockURLProtocol.swift
//  SophonTestSupport
//
//  Returns a fixed sequence of canned responses, one per request, so a retry
//  loop can be driven deterministically. Stubs and recorded requests are keyed
//  by request host: Swift Testing runs distinct suites in parallel in one
//  process, so provider suites that talk to different hosts never consume
//  each other's stubs. Within a host the last stub repeats if more requests
//  arrive than stubs were provided, and suites sharing a host must be
//  `.serialized`.
//

import Foundation

public final class LLMMockURLProtocol: URLProtocol {
    public struct Stub: Sendable {
        public let statusCode: Int
        public let body: Data
        public let headers: [String: String]

        public init(statusCode: Int, body: Data, headers: [String: String] = [:]) {
            self.statusCode = statusCode
            self.body = body
            self.headers = headers
        }

        public init(statusCode: Int, json: String, headers: [String: String] = [:]) {
            self.init(statusCode: statusCode, body: Data(json.utf8), headers: headers)
        }
    }

    // URLSession calls startLoading on its own worker queue while tests read on
    // the MainActor; the lock keeps the shared state coherent either way.
    private static let lock = NSLock()
    private nonisolated(unsafe) static var stubsByHost: [String: [Stub]] = [:]
    private nonisolated(unsafe) static var requestsByHost: [String: [URLRequest]] = [:]

    /// Queue `stubs` for requests to `host`, replacing any earlier queue.
    public static func setStubs(_ stubs: [Stub], for host: String) {
        lock.withLock { stubsByHost[host] = stubs }
    }

    /// Every request to `host` since the last `reset(host:)`, in order.
    public static func requests(for host: String) -> [URLRequest] {
        lock.withLock { requestsByHost[host] ?? [] }
    }

    public static func requestCount(for host: String) -> Int {
        requests(for: host).count
    }

    public static func reset(host: String) {
        lock.withLock {
            stubsByHost[host] = []
            requestsByHost[host] = []
        }
    }

    /// A session that routes every request through the mock.
    public static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LLMMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    // URLProtocol requirements are `class func`s, so `static` cannot override them.
    // swiftlint:disable static_over_final_class
    override public class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    // swiftlint:enable static_over_final_class

    override public func startLoading() {
        let host = request.url?.host() ?? ""
        let nextStub: Stub? = Self.lock.withLock {
            // Capture the body too: URLSession strips httpBody from the request it hands
            // to a protocol, so read the stream the caller left behind.
            var recorded = request
            if recorded.httpBody == nil, let stream = request.httpBodyStream {
                recorded.httpBody = Self.readAll(stream)
            }
            Self.requestsByHost[host, default: []].append(recorded)
            let stubs = Self.stubsByHost[host] ?? []
            guard !stubs.isEmpty else { return nil }
            let index = min((Self.requestsByHost[host]?.count ?? 1) - 1, stubs.count - 1)
            return stubs[index]
        }
        guard let stub = nextStub else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        guard let url = request.url ?? URL(string: "https://example.com"),
              let response = HTTPURLResponse(url: url, statusCode: stub.statusCode, httpVersion: nil, headerFields: stub.headers) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override public func stopLoading() {}

    private static func readAll(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 64 * 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
