import Foundation

/// `claude` CLI 的 Process 封装（TechSpec §09.6 / API-01 / API-02）。
final class ClaudeCLI {

    enum ClaudeCLIError: Error, LocalizedError {
        case notFound                       // CD-002
        case timedOut                       // CD-005 / KS-05
        case nonZeroExit(code: Int32, stderr: String)   // CD-006 / KS-06
        case invalidOutput(String)          // CD-007 / KS-06

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "Claude CLI not found in PATH"
            case .timedOut:
                return "Handoff generation timed out"
            case .nonZeroExit(_, let stderr):
                let head = String(stderr.prefix(100))
                return "Handoff generation failed: \(head)"
            case .invalidOutput:
                return "Claude returned unexpected output"
            }
        }
    }

    /// `claude -p ... --output-format json` 的结果结构（API-02）。
    private struct HandoffResponse: Decodable {
        let result: String?
    }

    private(set) var executableURL: URL?

    /// 检测 CLI 可用性 + 版本号（API-01）。失败 throw `.notFound`。
    @discardableResult
    func detectVersion() async throws -> String {
        guard let url = await ProcessRunner.which("claude") else {
            throw ClaudeCLIError.notFound
        }
        executableURL = url
        let result = try await ProcessRunner.run(
            executableURL: url,
            arguments: ["--version"],
            environment: ProcessRunner.loginShellEnvironment(),
            timeout: 5
        )
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isAvailable: Bool { executableURL != nil }

    /// 生成 handoff 摘要（API-02 / BR-017）。`environment` 由调用方注入代理（BR-035）。
    func runHandoff(
        sessionID: String,
        prompt: String,
        environment: [String: String],
        timeout: TimeInterval = 60
    ) async throws -> String {
        let url: URL
        if let executableURL {
            url = executableURL
        } else if let resolved = await ProcessRunner.which("claude") {
            executableURL = resolved
            url = resolved
        } else {
            throw ClaudeCLIError.notFound
        }

        let result = try await ProcessRunner.run(
            executableURL: url,
            arguments: ["-p", prompt, "--resume", sessionID, "--output-format", "json"],
            environment: environment,
            timeout: timeout
        )

        if result.timedOut {
            NSLog("[CD-005] Handoff timed out for session \(sessionID)")
            throw ClaudeCLIError.timedOut
        }
        guard result.exitCode == 0 else {
            NSLog("[CD-006] Handoff exit \(result.exitCode): \(result.stderr.prefix(100))")
            throw ClaudeCLIError.nonZeroExit(code: result.exitCode, stderr: result.stderr)
        }
        guard let data = result.stdout.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(HandoffResponse.self, from: data),
              let text = decoded.result, !text.isEmpty else {
            NSLog("[CD-007] Handoff JSON parse failed for session \(sessionID)")
            throw ClaudeCLIError.invalidOutput(result.stdout)
        }
        return text
    }
}
