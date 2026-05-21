import Foundation

/// reachability 测试结果（TechSpec §09.8）。
struct TestResult {
    let status: TestStatus
    let httpCode: Int?
    let latencyMs: Int?
    let errorDescription: String?
}

/// 用 `curl` 经代理探测 `api.anthropic.com` 可达性（TechSpec API-09 / BR-031，V1）。
///
/// 改用 curl 而非 URLSession：curl 的 `--proxy` 对 Clash/Surge 等本地代理最可靠，
/// 而 URLSession 的 connectionProxyDictionary 在部分 macOS 版本上对 HTTPS CONNECT
/// 隧道支持不稳定。
final class ProxyTester {

    static let probeURLString = "https://api.anthropic.com"
    private static let curlURL = URL(fileURLWithPath: "/usr/bin/curl")

    /// 单次 reachability 测试。proxy = nil 表示直连。
    func test(
        via proxy: URL?,
        timeout: TimeInterval = AppSettings.proxyReachabilityTimeoutSec
    ) async -> TestResult {
        var args = [
            "--max-time", "\(Int(timeout))",
            "-s", "-o", "/dev/null",
            "-w", "%{http_code} %{time_total}"
        ]
        if let proxy {
            args += ["--proxy", proxy.absoluteString]
        } else {
            args += ["--noproxy", "*"]   // disabled / 直连：忽略环境里的代理变量
        }
        args.append(Self.probeURLString)

        guard let result = try? await ProcessRunner.run(
            executableURL: Self.curlURL,
            arguments: args,
            timeout: timeout + 2
        ) else {
            return TestResult(status: .proxyNotResponding, httpCode: nil,
                              latencyMs: nil, errorDescription: "curl failed to launch")
        }

        if result.timedOut {
            return TestResult(status: .timeout, httpCode: nil,
                              latencyMs: nil, errorDescription: "timed out")
        }

        let fields = result.stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
        let code = fields.first.flatMap { Int($0) } ?? 0
        let latencyMs = fields.count > 1
            ? Int((Double(fields[1]) ?? 0) * 1000)
            : nil

        if AppSettings.reachableStatusCodes.contains(code) {
            return TestResult(status: .reachable, httpCode: code,
                              latencyMs: latencyMs, errorDescription: nil)
        }
        if code != 0 {
            // 到达了服务器但状态码不在白名单（含 5xx）
            return TestResult(status: .apiDown, httpCode: code,
                              latencyMs: latencyMs, errorDescription: "HTTP \(code)")
        }
        // code == 0：连接层失败，按 curl 退出码归类
        return TestResult(status: Self.mapCurlExit(result.exitCode), httpCode: nil,
                          latencyMs: nil, errorDescription: "curl exit \(result.exitCode)")
    }

    /// curl 退出码 → TestStatus（man curl: 5/6 解析失败，7 连接失败，28 超时）。
    static func mapCurlExit(_ exitCode: Int32) -> TestStatus {
        switch exitCode {
        case 28: return .timeout
        case 7: return .proxyNotResponding      // failed to connect to host/proxy
        case 5, 6: return .dnsFailed            // couldn't resolve proxy / host
        default: return .proxyNotResponding
        }
    }
}
