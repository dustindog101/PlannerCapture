import Foundation

final class GatewayStubURLProtocol: URLProtocol {
    struct StubResponse {
        var statusCode: Int
        var headers: [String: String] = [:]
        var body: Data = Data()
        var error: Error?
        var delay: TimeInterval = 0
    }

    struct CapturedRequest {
        let method: String
        let pathWithQuery: String
        let headers: [String: String]
    }

    private static let lock = NSLock()
    private static var stubsByRoute: [String: [StubResponse]] = [:]
    private static var capturedRequests: [CapturedRequest] = []
    private static var fallback: ((URLRequest) -> StubResponse)?

    override class func canInit(with request: URLRequest) -> Bool {
        guard let scheme = request.url?.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let request = self.request
        let method = request.httpMethod ?? "GET"
        let pathWithQuery = Self.pathWithQuery(for: request)
        let route = Self.routeKey(method: method, pathWithQuery: pathWithQuery)

        let stub = Self.dequeueStub(for: route, request: request)
        let headers = request.allHTTPHeaderFields ?? [:]
        Self.recordRequest(.init(method: method, pathWithQuery: pathWithQuery, headers: headers))

        let send: () -> Void = {
            if let error = stub.error {
                self.client?.urlProtocol(self, didFailWithError: error)
                return
            }

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: stub.statusCode,
                httpVersion: nil,
                headerFields: stub.headers
            )!
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: stub.body)
            self.client?.urlProtocolDidFinishLoading(self)
        }

        if stub.delay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + stub.delay, execute: send)
        } else {
            send()
        }
    }

    override func stopLoading() {}

    static func enqueue(_ stub: StubResponse, method: String, pathWithQuery: String) {
        lock.lock()
        defer { lock.unlock() }
        let key = routeKey(method: method, pathWithQuery: pathWithQuery)
        stubsByRoute[key, default: []].append(stub)
    }

    static func setFallback(_ fallback: @escaping (URLRequest) -> StubResponse) {
        lock.lock()
        defer { lock.unlock() }
        self.fallback = fallback
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        stubsByRoute.removeAll()
        capturedRequests.removeAll()
        fallback = nil
    }

    static func clearCapturedRequests() {
        lock.lock()
        defer { lock.unlock() }
        capturedRequests.removeAll()
    }

    static func requests(matching method: String, pathWithQuery: String) -> [CapturedRequest] {
        lock.lock()
        defer { lock.unlock() }
        return capturedRequests.filter { $0.method == method.uppercased() && $0.pathWithQuery == pathWithQuery }
    }

    static func allCapturedRequests() -> [CapturedRequest] {
        lock.lock()
        defer { lock.unlock() }
        return capturedRequests
    }

    private static func routeKey(for request: URLRequest) -> String {
        let method = request.httpMethod ?? "GET"
        return routeKey(method: method, pathWithQuery: pathWithQuery(for: request))
    }

    private static func routeKey(method: String, pathWithQuery: String) -> String {
        "\(method.uppercased()) \(pathWithQuery)"
    }

    private static func pathWithQuery(for request: URLRequest) -> String {
        let path = request.url?.path ?? "/"
        let query = request.url?.query.map { "?\($0)" } ?? ""
        return "\(path)\(query)"
    }

    private static func dequeueStub(for route: String, request: URLRequest) -> StubResponse {
        lock.lock()
        defer { lock.unlock() }

        if var queue = stubsByRoute[route], !queue.isEmpty {
            let head = queue.removeFirst()
            stubsByRoute[route] = queue
            return head
        }

        if let fallback {
            return fallback(request)
        }

        return StubResponse(statusCode: 500, body: Data("{\"error\":\"Missing test stub\"}".utf8))
    }

    private static func recordRequest(_ request: CapturedRequest) {
        lock.lock()
        defer { lock.unlock() }
        capturedRequests.append(request)
    }
}
