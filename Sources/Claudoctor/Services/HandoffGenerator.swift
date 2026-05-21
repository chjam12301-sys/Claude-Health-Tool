import Foundation

/// Park & Restart 的 handoff 笔记生成（TechSpec §08.3 / BR-015~017 / API-02，V1）。
struct HandoffGenerator {

    /// 固定 handoff prompt（TechSpec §05.1 / BR-015），V1 不可由用户修改。
    static let prompt = """
    总结本会话：做了什么、关键决策、下次续点。≤300字，markdown 格式，分三个章节标题：## 做了什么 / ## 关键决策 / ## 下次续点。第三章节必须给出明确的下一步动作描述。
    """

    let cli: ClaudeCLI
    let fileManager: FileManager

    init(cli: ClaudeCLI, fileManager: FileManager = .default) {
        self.cli = cli
        self.fileManager = fileManager
    }

    /// handoff 写入路径（BR-016）：`<project_root>/.notes/yyyy-MM-dd-HHmm.md`。
    static func targetPath(projectRoot: URL, now: Date = Date()) -> URL {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return projectRoot
            .appendingPathComponent(".notes", isDirectory: true)
            .appendingPathComponent("\(f.string(from: now)).md")
    }

    /// 生成 handoff 并写入项目 `.notes/`。失败抛出 `ClaudeCLI.ClaudeCLIError`。
    /// 返回写入的文件 URL。
    func generate(
        for session: SessionInfo,
        proxy: ProxyConfig,
        timeout: TimeInterval = 60,
        now: Date = Date()
    ) async throws -> URL {
        let env = ProxyEnvBuilder.subprocessEnv(
            base: ProcessRunner.loginShellEnvironment(), proxy: proxy)

        let summary = try await cli.runHandoff(
            sessionID: session.id,
            prompt: Self.prompt,
            environment: env,
            timeout: timeout
        )

        let projectRoot = URL(fileURLWithPath: session.projectPath, isDirectory: true)
        let notesDir = projectRoot.appendingPathComponent(".notes", isDirectory: true)
        try ensureNotesDirectory(notesDir)

        let target = Self.targetPath(projectRoot: projectRoot, now: now)
        try summary.write(to: target, atomically: true, encoding: .utf8)
        return target
    }

    /// 首次写入时创建 `.notes/` 与说明 README（TechSpec §10）。
    private func ensureNotesDirectory(_ notesDir: URL) throws {
        if !fileManager.fileExists(atPath: notesDir.path) {
            try fileManager.createDirectory(at: notesDir, withIntermediateDirectories: true)
        }
        let readme = notesDir.appendingPathComponent("README.md")
        if !fileManager.fileExists(atPath: readme.path) {
            let body = """
            # Session handoff notes

            Claudoctor writes a short summary here every time you Park & Restart a
            Claude Code session, so a fresh session can pick up where the last one
            left off. Read the most recent file before continuing your work.
            """
            try? body.write(to: readme, atomically: true, encoding: .utf8)
        }
    }
}
