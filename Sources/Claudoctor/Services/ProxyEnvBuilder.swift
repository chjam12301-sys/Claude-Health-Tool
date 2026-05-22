import Foundation

/// 构造 subprocess env 与 shell prefix（TechSpec §09.8 / BR-035 / BR-036，V1）。
enum ProxyEnvBuilder {

    static let noProxyValue = "localhost,127.0.0.1,::1"

    /// 给 Process subprocess 注入代理 env，大小写各一版（BR-035）。
    /// proxy 关闭 / 直连时原样返回 base（不注入）。
    static func subprocessEnv(
        base: [String: String],
        proxy: ProxyConfig
    ) -> [String: String] {
        var env = base
        guard let httpURL = proxy.effectiveURL?.absoluteString else {
            return env
        }
        let socksURL = proxy.effectiveSOCKSURL?.absoluteString ?? httpURL
        let pairs: [(String, String)] = [
            ("HTTPS_PROXY", httpURL),
            ("HTTP_PROXY", httpURL),
            ("ALL_PROXY", socksURL),
            ("NO_PROXY", noProxyValue)
        ]
        for (key, value) in pairs {
            env[key] = value
            env[key.lowercased()] = value
        }
        return env
    }

    /// 给 AppleScript / shell `do script` 构造前缀（BR-036）。
    /// proxy 关闭 / 直连时返回空字符串。
    static func shellPrefix(proxy: ProxyConfig) -> String {
        guard let httpURL = proxy.effectiveURL?.absoluteString else { return "" }
        let socksURL = proxy.effectiveSOCKSURL?.absoluteString ?? httpURL
        return "export "
            + "HTTPS_PROXY=\(httpURL.shellQuoted) "
            + "HTTP_PROXY=\(httpURL.shellQuoted) "
            + "ALL_PROXY=\(socksURL.shellQuoted) "
            + "NO_PROXY=\(noProxyValue.shellQuoted) && "
    }
}
