import XCTest
@testable import Claudoctor

final class ProxyTests: XCTestCase {

    // MARK: URL validation (BR-038)

    func testValidProxyURLs() {
        XCTAssertTrue(ProxyConfig.isValidProxyURLString("http://127.0.0.1:7890"))
        XCTAssertTrue(ProxyConfig.isValidProxyURLString("https://proxy.local:8080"))
        XCTAssertTrue(ProxyConfig.isValidProxyURLString("socks5://127.0.0.1:7891"))
    }

    func testInvalidProxyURLs() {
        XCTAssertFalse(ProxyConfig.isValidProxyURLString("127.0.0.1:7890"))   // no scheme
        XCTAssertFalse(ProxyConfig.isValidProxyURLString("http://127.0.0.1")) // no port
        XCTAssertFalse(ProxyConfig.isValidProxyURLString("ftp://host:21"))    // bad scheme
        XCTAssertFalse(ProxyConfig.isValidProxyURLString(""))
    }

    // MARK: effectiveURL (§04.6)

    func testEffectiveURLByMode() {
        var config = ProxyConfig()
        config.manualHTTPURL = URL(string: "http://127.0.0.1:7890")
        config.detectedURL = URL(string: "http://127.0.0.1:7993")

        config.mode = .disabled
        XCTAssertNil(config.effectiveURL)

        config.mode = .manual
        XCTAssertEqual(config.effectiveURL?.absoluteString, "http://127.0.0.1:7890")

        config.mode = .autoDetect
        XCTAssertEqual(config.effectiveURL?.absoluteString, "http://127.0.0.1:7993")
    }

    func testEffectiveSOCKSURLAutoDetectConversion() {
        var config = ProxyConfig()
        config.mode = .autoDetect
        config.detectedURL = URL(string: "http://127.0.0.1:7890")
        XCTAssertEqual(config.effectiveSOCKSURL?.absoluteString, "socks5://127.0.0.1:7890")
    }

    // MARK: ProxyEnvBuilder (BR-035 / BR-036)

    func testSubprocessEnvInjectsEightVars() {
        var config = ProxyConfig()
        config.mode = .manual
        config.manualHTTPURL = URL(string: "http://127.0.0.1:7890")

        let env = ProxyEnvBuilder.subprocessEnv(base: [:], proxy: config)
        for key in ["HTTPS_PROXY", "HTTP_PROXY", "ALL_PROXY", "NO_PROXY"] {
            XCTAssertNotNil(env[key], "missing \(key)")
            XCTAssertNotNil(env[key.lowercased()], "missing \(key.lowercased())")
        }
        XCTAssertEqual(env["HTTPS_PROXY"], "http://127.0.0.1:7890")
    }

    func testSubprocessEnvNoInjectionWhenDisabled() {
        var config = ProxyConfig()
        config.mode = .disabled
        let env = ProxyEnvBuilder.subprocessEnv(base: ["PATH": "/usr/bin"], proxy: config)
        XCTAssertNil(env["HTTPS_PROXY"])
        XCTAssertEqual(env["PATH"], "/usr/bin")
    }

    func testShellPrefixEmptyWhenDisabled() {
        var config = ProxyConfig()
        config.mode = .disabled
        XCTAssertEqual(ProxyEnvBuilder.shellPrefix(proxy: config), "")
    }

    func testShellPrefixContainsExport() {
        var config = ProxyConfig()
        config.mode = .manual
        config.manualHTTPURL = URL(string: "http://127.0.0.1:7890")
        let prefix = ProxyEnvBuilder.shellPrefix(proxy: config)
        XCTAssertTrue(prefix.contains("export HTTPS_PROXY="))
        XCTAssertTrue(prefix.hasSuffix("&& "))
    }
}
