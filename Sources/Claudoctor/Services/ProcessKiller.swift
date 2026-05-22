import Foundation

/// 关闭某项目目录下正在运行的 `claude` 交互进程（Park 时清理旧会话）。Best-effort。
///
/// 用进程的工作目录(cwd)精确匹配——只杀 cwd 等于该项目目录的 claude，
/// 不会误伤其他项目或其他程序。
enum ProcessKiller {

    static func killClaudeSessions(inProjectPath path: String) async {
        let candidates = await claudePIDs()
        guard !candidates.isEmpty else { return }

        let target = (path as NSString).standardizingPath
        for pid in candidates {
            guard let cwd = await workingDirectory(of: pid) else { continue }
            if (cwd as NSString).standardizingPath == target {
                _ = try? await ProcessRunner.run(
                    executableURL: URL(fileURLWithPath: "/bin/kill"),
                    arguments: ["-TERM", "\(pid)"],
                    timeout: 5)
                NSLog("[Claudoctor] Closed old claude session pid \(pid) in \(target)")
            }
        }
    }

    /// 命令行里含 "claude" 的进程 PID（claude CLI 的 argv 含 claude；本应用名为 Claudoctor，不匹配）。
    private static func claudePIDs() async -> [Int] {
        guard let result = try? await ProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/pgrep"),
            arguments: ["-f", "claude"],
            timeout: 5
        ) else { return [] }
        return result.stdout
            .split(whereSeparator: { $0 == "\n" })
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// 用 lsof 取某 PID 的工作目录。
    private static func workingDirectory(of pid: Int) async -> String? {
        guard let result = try? await ProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/sbin/lsof"),
            arguments: ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"],
            timeout: 5
        ) else { return nil }
        for line in result.stdout.split(whereSeparator: { $0 == "\n" }) where line.hasPrefix("n") {
            return String(line.dropFirst())
        }
        return nil
    }
}
