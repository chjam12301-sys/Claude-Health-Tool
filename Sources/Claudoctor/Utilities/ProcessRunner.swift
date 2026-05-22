import Foundation

/// 执行结果。
struct ProcessResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let timedOut: Bool
}

enum ProcessRunnerError: Error, LocalizedError {
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let msg): return "Failed to launch process: \(msg)"
        }
    }
}

/// 跨任务可写的超时标记。仅在结构化并发的子任务全部完成后读取，保证可见性。
private final class TimeoutFlag: @unchecked Sendable {
    var value = false
}

/// `Foundation.Process` 的 async 封装，支持超时与显式 env 注入（TechSpec §09.6）。
enum ProcessRunner {

    /// 运行可执行文件，捕获 stdout/stderr。超时后 terminate 进程并标记 `timedOut`。
    static func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]? = nil,
        currentDirectory: URL? = nil,
        timeout: TimeInterval
    ) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        if let environment { process.environment = environment }
        if let currentDirectory { process.currentDirectoryURL = currentDirectory }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw ProcessRunnerError.launchFailed(error.localizedDescription)
        }

        // 关掉父进程持有的管道写端：否则子进程退出后 readToEnd 仍等不到 EOF，
        // 会永久挂起（curl 早已结束但 run() 不返回，导致预检/检测一直卡住）。
        try? stdoutPipe.fileHandleForWriting.close()
        try? stderrPipe.fileHandleForWriting.close()

        // 后台读管道，避免输出填满 64KB 缓冲导致死锁；进程退出后管道 EOF，读结束。
        async let outData = readToEnd(stdoutPipe.fileHandleForReading)
        async let errData = readToEnd(stderrPipe.fileHandleForReading)

        let didTimeout = TimeoutFlag()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await blockingWait(process) }
            group.addTask {
                let nanos = UInt64(max(0, timeout) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
                if process.isRunning {
                    didTimeout.value = true
                    process.terminate()   // 解除 blockingWait 的阻塞
                }
            }
            // 任一子任务完成后取消另一个，并 drain 直到全部结束，保证 flag 可见。
            await group.next()
            group.cancelAll()
            for await _ in group {}
        }

        let stdout = String(data: await outData, encoding: .utf8) ?? ""
        let stderr = String(data: await errData, encoding: .utf8) ?? ""

        return ProcessResult(
            exitCode: process.terminationStatus,
            stdout: stdout,
            stderr: stderr,
            timedOut: didTimeout.value
        )
    }

    /// 解析可执行文件在 PATH 中的完整路径（`which <name>`）。找不到返回 nil。
    static func which(_ command: String) async -> URL? {
        let envURL = URL(fileURLWithPath: "/usr/bin/env")
        guard let result = try? await run(
            executableURL: envURL,
            arguments: ["which", command],
            environment: loginShellEnvironment(),
            timeout: 5
        ) else { return nil }

        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.exitCode == 0, !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// GUI app 由 launchd 启动，PATH 很贫瘠。补上常见 CLI 安装目录，
    /// 让 `which claude` 能找到 Homebrew / npm 全局安装的 claude。
    static func loginShellEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let extraPaths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(NSHomeDirectory())/.local/bin",
            "\(NSHomeDirectory())/.npm-global/bin",
            "\(NSHomeDirectory())/.bun/bin"
        ]
        let existing = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = (extraPaths + [existing]).joined(separator: ":")
        return env
    }

    private static func blockingWait(_ process: Process) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .utility).async {
                process.waitUntilExit()
                continuation.resume()
            }
        }
    }

    private static func readToEnd(_ handle: FileHandle) async -> Data {
        await withCheckedContinuation { (continuation: CheckedContinuation<Data, Never>) in
            DispatchQueue.global(qos: .utility).async {
                let data = (try? handle.readToEnd()) ?? Data()
                continuation.resume(returning: data)
            }
        }
    }
}
