import Foundation

/// 代理工作模式（TechSpec §04.6，V1）。
enum ProxyMode: String, Codable {
    case autoDetect     // 启动时探测 + 周期重测
    case manual         // 用户填 URL，不自动探测
    case disabled       // 不用代理（直连 / 系统已配 launchctl env）
}

/// reachability 测试结果状态（TechSpec §04.6）。
enum TestStatus: String, Codable {
    case notTested
    case reachable             // 200/401/403
    case proxyNotResponding    // TCP connection refused
    case timeout               // > 5s no response
    case dnsFailed             // DNS resolution failed
    case apiDown               // HTTP 5xx

    var isHealthy: Bool { self == .reachable }

    var displayString: String {
        switch self {
        case .notTested: return "Not tested yet"
        case .reachable: return "Reachable"
        case .proxyNotResponding: return "Proxy not responding"
        case .timeout: return "Connection timed out"
        case .dnsFailed: return "DNS resolution failed"
        case .apiDown: return "Server returned 5xx"
        }
    }
}

/// 代理配置（TechSpec §04.6，V1）。
struct ProxyConfig: Codable, Equatable {
    var mode: ProxyMode = .autoDetect
    var manualHTTPURL: URL?
    var manualSOCKSURL: URL?          // 可选，留空则用 manualHTTPURL 当 ALL_PROXY
    var detectedURL: URL?             // mode = .autoDetect 自动填充
    var lastTestStatus: TestStatus = .notTested
    var lastTestedAt: Date?
    var lastTestLatencyMs: Int?

    /// 当前生效的代理 URL（nil 表示直连）。
    var effectiveURL: URL? {
        switch mode {
        case .disabled: return nil
        case .manual: return manualHTTPURL
        case .autoDetect: return detectedURL
        }
    }

    /// 当前生效的 SOCKS URL（用于 ALL_PROXY）。
    var effectiveSOCKSURL: URL? {
        switch mode {
        case .disabled: return nil
        case .manual: return manualSOCKSURL ?? manualHTTPURL
        case .autoDetect:
            guard let url = detectedURL,
                  let host = url.host,
                  let port = url.port else { return nil }
            return URL(string: "socks5://\(host):\(port)")
        }
    }
}

// MARK: - URL 校验（BR-038）

extension ProxyConfig {
    static let allowedSchemes: Set<String> = ["http", "https", "socks5"]

    /// 代理 URL 必须符合 `<scheme>://<host>:<port>`，scheme ∈ {http, https, socks5}。
    static func isValidProxyURLString(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              allowedSchemes.contains(scheme),
              let host = url.host, !host.isEmpty,
              url.port != nil else {
            return false
        }
        return true
    }
}
