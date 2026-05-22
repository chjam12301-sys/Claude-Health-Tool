import CFNetwork
import Foundation

/// 候选代理探测 + 验证（TechSpec §08.6 F6 / §09.8，V1）。
///
/// 不再用 NWConnection 做 TCP 端口预探测——它的建连超时（300ms）会把开着的端口
/// 误判为关闭（如 7993），导致自动检测失败而手动成功。改为直接用 curl 逐个验证
/// 候选（与手动同一条可靠路径）：localhost 关闭端口的 refused 是秒级返回，代价可控。
final class ProxyDetector {
    private let tester: ProxyTester

    init(tester: ProxyTester = ProxyTester()) {
        self.tester = tester
    }

    /// 跑一次完整探测：系统代理 + 常见端口候选 → 逐个 curl 验证 → 返回第一个可达（或 nil）。
    func detect() async -> URL? {
        for proxy in candidates() {
            let result = await tester.test(via: proxy, timeout: 4)
            if result.status == .reachable {
                return proxy
            }
        }
        return nil
    }

    /// 候选列表：系统代理（最高优先）+ 常见本地端口，去重保序。
    func candidates() -> [URL] {
        var list: [URL] = []
        if let system = systemProxyCandidate() {
            list.append(system)
        }
        list.append(contentsOf: AppSettings.commonProxyPorts.compactMap {
            URL(string: "http://127.0.0.1:\($0)")
        })
        var seen = Set<String>()
        return list.filter { seen.insert($0.absoluteString).inserted }
    }

    /// 读取 macOS 系统网络代理设置（很多代理 App 会写入），作为最高优先候选。
    /// HTTPS / HTTP 代理用 `http://` scheme（CONNECT 隧道），SOCKS 用 `socks5://`。
    func systemProxyCandidate() -> URL? {
        guard let raw = CFNetworkCopySystemProxySettings()?.takeRetainedValue(),
              let dict = raw as? [String: Any] else { return nil }

        func enabled(_ key: CFString) -> Bool { (dict[key as String] as? Int) == 1 }
        func string(_ key: CFString) -> String? { dict[key as String] as? String }
        func int(_ key: CFString) -> Int? { dict[key as String] as? Int }

        if enabled(kCFNetworkProxiesHTTPSEnable),
           let host = string(kCFNetworkProxiesHTTPSProxy),
           let port = int(kCFNetworkProxiesHTTPSPort) {
            return URL(string: "http://\(host):\(port)")
        }
        if enabled(kCFNetworkProxiesHTTPEnable),
           let host = string(kCFNetworkProxiesHTTPProxy),
           let port = int(kCFNetworkProxiesHTTPPort) {
            return URL(string: "http://\(host):\(port)")
        }
        if enabled(kCFNetworkProxiesSOCKSEnable),
           let host = string(kCFNetworkProxiesSOCKSProxy),
           let port = int(kCFNetworkProxiesSOCKSPort) {
            return URL(string: "socks5://\(host):\(port)")
        }
        return nil
    }
}
