import Foundation

/// reachability 测试结果（TechSpec §09.8）。
struct TestResult {
    let status: TestStatus
    let httpCode: Int?
    let latencyMs: Int?
    let errorDescription: String?
}

/// 用现成代理 URL 测 `api.anthropic.com`（TechSpec §09.8 / API-09 / BR-031，V1）。
final class ProxyTester {

    static let probeURL = URL(string: "https://api.anthropic.com")!

    /// 单次 reachability 测试。proxy = nil 表示直连。
    func test(
        via proxy: URL?,
        timeout: TimeInterval = AppSettings.proxyReachabilityTimeoutSec
    ) async -> TestResult {
        let configuration: URLSessionConfiguration
        if let proxy {
            configuration = .withProxy(proxy)
        } else {
            configuration = .ephemeral
        }
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        var request = URLRequest(url: Self.probeURL)
        request.httpMethod = "GET"

        let start = Date()
        do {
            let (_, response) = try await session.data(for: request)
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            guard let http = response as? HTTPURLResponse else {
                return TestResult(status: .apiDown, httpCode: nil,
                                  latencyMs: latency, errorDescription: "Non-HTTP response")
            }
            let code = http.statusCode
            if AppSettings.reachableStatusCodes.contains(code) {
                return TestResult(status: .reachable, httpCode: code,
                                  latencyMs: latency, errorDescription: nil)
            }
            return TestResult(status: .apiDown, httpCode: code,
                              latencyMs: latency, errorDescription: "HTTP \(code)")
        } catch {
            let ns = error as NSError
            return TestResult(status: Self.mapURLError(ns), httpCode: nil,
                              latencyMs: nil, errorDescription: ns.localizedDescription)
        }
    }

    /// 把 URLError code 映射到 TestStatus（API-09）。
    static func mapURLError(_ error: NSError) -> TestStatus {
        guard error.domain == NSURLErrorDomain else { return .proxyNotResponding }
        switch error.code {
        case NSURLErrorTimedOut:
            return .timeout
        case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
            return .dnsFailed
        case NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost,
             NSURLErrorNotConnectedToInternet:
            return .proxyNotResponding
        default:
            return .proxyNotResponding
        }
    }
}

extension URLSessionConfiguration {
    /// 显式走代理的 ephemeral 配置（TechSpec §09.8）。
    static func withProxy(_ proxy: URL) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        guard let host = proxy.host, let port = proxy.port else { return config }

        let isSOCKS = (proxy.scheme?.lowercased() == "socks5")
        if isSOCKS {
            config.connectionProxyDictionary = [
                "SOCKSEnable": 1,
                "SOCKSProxy": host,
                "SOCKSPort": port
            ]
        } else {
            config.connectionProxyDictionary = [
                "HTTPSEnable": 1,
                "HTTPSProxy": host,
                "HTTPSPort": port,
                "HTTPEnable": 1,
                "HTTPProxy": host,
                "HTTPPort": port
            ]
        }
        return config
    }
}
