import Foundation

final class MockGitHubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Stub {
        let statusCode: Int
        let data: Data?
        let headers: [String: String]

        init(statusCode: Int = 200, data: Data? = nil, headers: [String: String] = [:]) {
            self.statusCode = statusCode
            self.data = data
            self.headers = headers
        }
    }

    private static let state = NSLock()

    nonisolated(unsafe) private static var _stubs: [Stub] = []
    nonisolated(unsafe) private static var _error: Error?
    nonisolated(unsafe) private static var _requestedURLs: [URL] = []

    static var stubs: [Stub] {
        get { state.lock(); defer { state.unlock() }; return _stubs }
        set { state.lock(); _stubs = newValue; state.unlock() }
    }

    static var error: Error? {
        get { state.lock(); defer { state.unlock() }; return _error }
        set { state.lock(); _error = newValue; state.unlock() }
    }

    static var requestedURLs: [URL] {
        state.lock(); defer { state.unlock() }; return _requestedURLs
    }

    static func reset() {
        state.lock()
        _stubs = []
        _error = nil
        _requestedURLs = []
        state.unlock()
    }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.protocolClasses = [MockGitHubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    private static func nextStub() -> Stub? {
        state.lock(); defer { state.unlock() }
        guard !_stubs.isEmpty else { return nil }
        if _stubs.count > 1 { return _stubs.removeFirst() }
        return _stubs[0]
    }

    override func startLoading() {
        Self.state.lock()
        Self._requestedURLs.append(request.url ?? URL(string: "about:blank")!)
        let failure = Self._error
        Self.state.unlock()

        if let failure {
            client?.urlProtocol(self, didFailWithError: failure)
            return
        }

        guard let stub = Self.nextStub(), let url = request.url else {
            let failure = URLError(.badServerResponse)
            client?.urlProtocol(self, didFailWithError: failure)
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: stub.headers
        )!

        if (300 ..< 400).contains(stub.statusCode),
           let location = stub.headers["Location"],
           let target = URL(string: location, relativeTo: url)?.absoluteURL {
            let redirect = HTTPURLResponse(
                url: target,
                statusCode: stub.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: stub.headers
            )!
            var redirected = URLRequest(url: target)
            redirected.httpMethod = request.httpMethod
            client?.urlProtocol(self, wasRedirectedTo: redirected, redirectResponse: redirect)
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let data = stub.data {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}