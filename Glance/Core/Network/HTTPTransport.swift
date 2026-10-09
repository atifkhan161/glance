import Foundation

enum HTTPStatusMapper {
    static func error(for http: HTTPURLResponse) -> GlanceError? {
        let status = http.statusCode
        guard (200 ..< 300).contains(status) == false else { return nil }
        switch status {
        case 401, 403:
            return .unauthorized
        case 429:
            return .rateLimited(retryAfter: retryAfter(http))
        default:
            return .httpStatus(status)
        }
    }

    static func retryAfter(_ http: HTTPURLResponse) -> Double? {
        guard let raw = http.value(forHTTPHeaderField: "Retry-After") else { return nil }
        return Double(raw)
    }
}

/// Owns request execution, status mapping, and error recording. It deliberately
/// does **not** own retry: the clients differ today (`OpenRouterClient` retries
/// 429s with a capped backoff, `GitHubClient` reads `Retry-After` on 403,
/// `GitHubTrendingClient` does not retry) and centralizing that would silently
/// change network behaviour.
struct HTTPTransport: Sendable {
    let subsystem: String
    private let session: URLSession

    init(session: URLSession? = nil, subsystem: String) {
        self.session = session ?? Self.makeSession()
        self.subsystem = subsystem
    }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 15
        config.waitsForConnectivity = false
        if #available(iOS 16.0, *) {
            config.tlsMinimumSupportedProtocolVersion = .TLSv12
        }
        return URLSession(configuration: config)
    }

    func data(for request: URLRequest, hint: String? = nil) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            let http = try validated(response, request: request, hint: hint)
            return (data, http)
        } catch let error as GlanceError {
            throw error
        } catch let error as URLError {
            if isCancellation(error) {
                recordCancellation(request: request, hint: hint)
                throw CancellationError()
            }
            let mapped = GlanceError.networkError("\(subsystem): \(error.localizedDescription)")
            record(mapped, request: request, hint: hint)
            throw mapped
        }
    }

    func bytes(for request: URLRequest, hint: String? = nil) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        do {
            let (bytes, response) = try await session.bytes(for: request)
            let http = try validated(response, request: request, hint: hint)
            return (bytes, http)
        } catch let error as GlanceError {
            throw error
        } catch let error as URLError {
            if isCancellation(error) {
                recordCancellation(request: request, hint: hint)
                throw CancellationError()
            }
            let mapped = GlanceError.networkError("\(subsystem): \(error.localizedDescription)")
            record(mapped, request: request, hint: hint)
            throw mapped
        }
    }

    /// A cancelled request is lifecycle, not failure: the user left the card, or a
    /// refresh superseded an in-flight one. URLSession surfaces cancellation as a
    /// `URLError`, so without this check every navigation away logs an error.
    private func isCancellation(_ error: URLError) -> Bool {
        error.code == .cancelled || Task.isCancelled
    }

    private func validated(
        _ response: URLResponse,
        request: URLRequest,
        hint: String?
    ) throws -> HTTPURLResponse {
        guard let http = response as? HTTPURLResponse else {
            let error = GlanceError.networkUnavailable
            record(error, request: request, hint: hint)
            throw error
        }
        if let error = HTTPStatusMapper.error(for: http) {
            record(error, request: request, hint: hint)
            throw error
        }
        return http
    }

    /// Recording happens where the `GlanceError` is constructed — never inside a
    /// `catch let error as GlanceError { throw error }` branch, which would report
    /// the same failure twice. The mirror write can never fail the caller: a log
    /// write must not propagate into the operation being logged.
    private func record(_ error: GlanceError, request: URLRequest, hint: String?) {
        let detail = error.logDetail
        let identity = request.url.map { URLRedactor.describe($0, hint: hint) } ?? hint ?? "unknown host"
        let subsystem = subsystem
        Task {
            await AppLog.shared.record(
                .error,
                subsystem: subsystem,
                message: "\(identity): \(detail)",
                detail: detail
            )
        }
    }

    private func recordCancellation(request: URLRequest, hint: String?) {
        let identity = request.url.map { URLRedactor.describe($0, hint: hint) } ?? hint ?? "unknown host"
        let subsystem = subsystem
        Task {
            await AppLog.shared.record(.info, subsystem: subsystem, message: "\(identity): cancelled")
        }
    }
}