import Foundation
import Network

/// 端口探测 + 候选代理验证（TechSpec §08.6 F6 / §09.8 / BR-029 / BR-030，V1）。
final class ProxyDetector {
    private let tester: ProxyTester
    private let probeQueue = DispatchQueue(label: "com.sunnycao.claudoctor.proxyprobe")

    init(tester: ProxyTester = ProxyTester()) {
        self.tester = tester
    }

    /// 跑一次完整探测：扫端口 → 验证候选 → 返回第一个可达代理（或 nil）。
    func detect() async -> URL? {
        let candidates = await scanPorts()
        for proxy in candidates {
            let result = await tester.test(
                via: proxy, timeout: AppSettings.proxyReachabilityTimeoutSec)
            if result.status == .reachable {
                return proxy
            }
        }
        return nil
    }

    /// 并发探测 commonProxyPorts，返回连通端口对应的 `http://127.0.0.1:<port>`，
    /// 保持 commonProxyPorts 的优先级顺序（BR-029）。
    func scanPorts() async -> [URL] {
        let openPorts = await withTaskGroup(of: (Int, Bool).self) { group -> Set<Int> in
            for port in AppSettings.commonProxyPorts {
                group.addTask { (port, await self.probePort(port)) }
            }
            var result = Set<Int>()
            for await (port, isOpen) in group where isOpen {
                result.insert(port)
            }
            return result
        }
        return AppSettings.commonProxyPorts
            .filter { openPorts.contains($0) }
            .compactMap { URL(string: "http://127.0.0.1:\($0)") }
    }

    /// 单端口 TCP 探测，超时 300ms（BR-030）。
    func probePort(_ port: Int) async -> Bool {
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else { return false }

        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let connection = NWConnection(host: "127.0.0.1", port: nwPort, using: .tcp)
            let once = ResumeOnce()

            func finish(_ value: Bool) {
                guard once.tryResume() else { return }
                connection.cancel()
                continuation.resume(returning: value)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(true)
                case .failed, .cancelled:
                    finish(false)
                default:
                    break
                }
            }
            connection.start(queue: probeQueue)

            probeQueue.asyncAfter(
                deadline: .now() + .milliseconds(AppSettings.proxyPortProbeTimeoutMs)
            ) {
                finish(false)
            }
        }
    }
}

/// 线程安全的"只 resume 一次"守卫。
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func tryResume() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}
