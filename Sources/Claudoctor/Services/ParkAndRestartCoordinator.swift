import Foundation

/// Park & Restart 按钮 / 流程的 UI 状态机（TechSpec §08.3，V1）。
enum ParkPhase: Equatable {
    case idle
    case preflight
    case generatingHandoff
    case archiving
    case openingTerminal

    var label: String? {
        switch self {
        case .idle: return nil
        case .preflight: return "Pre-flight check..."
        case .generatingHandoff: return "Generating handoff..."
        case .archiving: return "Archiving..."
        case .openingTerminal: return "Opening terminal..."
        }
    }
}

/// 编排 Park & Restart 完整流程 F3（TechSpec §08.3 / BR-018 / BR-033 / BR-034，V1）。
@MainActor
final class ParkAndRestartCoordinator: ObservableObject {
    @Published private(set) var phase: ParkPhase = .idle

    /// 流程对外部状态的回写钩子。
    struct Hooks {
        let updateProxyStatus: (TestResult) -> Void
        let sessionsChanged: () -> Void
        let dismissPanel: () -> Void
    }

    private let tester: ProxyTester
    private let cli: ClaudeCLI
    private let notifications: NotificationService

    init(tester: ProxyTester, cli: ClaudeCLI, notifications: NotificationService) {
        self.tester = tester
        self.cli = cli
        self.notifications = notifications
    }

    var isRunning: Bool { phase != .idle }

    /// 执行 Park & Restart。`session` 应为活跃 session（BR-007，由调用方确定）。
    /// `autoGrantPermissions = true` 时，新会话用 `claude --dangerously-skip-permissions`
    /// 启动，跳过所有权限确认。
    func execute(
        session: SessionInfo,
        settings: AppSettings,
        claudeCLIAvailable: Bool,
        autoGrantPermissions: Bool = false,
        hooks: Hooks
    ) async {
        guard phase == .idle else { return }
        defer { phase = .idle }

        // Step 0b：CLI 可用性（KS-02）
        guard claudeCLIAvailable else {
            notifications.send(subtitle: loc("Claude CLI not found"),
                               body: loc("Install Claude Code or fix your PATH."))
            return
        }

        // Step 0c：pre-flight（BR-033 / BR-034）。失败立即中止，不动原 session。
        if !settings.skipPreflightOnPark {
            phase = .preflight
            let result = await tester.test(via: settings.proxyConfig.effectiveURL)
            hooks.updateProxyStatus(result)
            guard result.status == .reachable else {
                notifications.send(subtitle: loc("Pre-flight failed"),
                                   body: locf("%@. Original session preserved.",
                                              loc(result.status.displayString)))
                return
            }
        }

        // Step 1：关掉旧会话的 claude 交互进程。在归档前杀，避免它退出时把 .jsonl 写回原位。
        await ProcessKiller.killClaudeSessions(inProjectPath: session.projectPath)

        // Step 2：生成 handoff（BR-017）。失败仍继续（BR-018 / KS-05 / KS-06 / KS-12）。
        phase = .generatingHandoff
        var handoffPath: URL?
        let generator = HandoffGenerator(cli: cli)
        do {
            handoffPath = try await generator.generate(for: session, proxy: settings.proxyConfig)
        } catch {
            NSLog("[CD-006] Handoff failed: \(error.localizedDescription)")
            handoffPath = nil
        }

        // Step 4：归档原 session（复用 Archiver）。失败则中止，不开终端（让用户排查）。
        phase = .archiving
        let archiver = Archiver(archiveDirectory: settings.archiveDirectory)
        do {
            try archiver.archive(session)
            hooks.sessionsChanged()
        } catch {
            notifications.send(subtitle: loc("Park failed"),
                               body: locf("Couldn't archive session: %@", error.localizedDescription))
            return
        }

        // Step 6：启动新终端（BR-036）。失败弹 KS-07，但仍视为已 park。
        phase = .openingTerminal
        let projectRoot = URL(fileURLWithPath: session.projectPath, isDirectory: true)
        var baseCommand = autoGrantPermissions
            ? "claude --dangerously-skip-permissions"
            : "claude"
        // 接力：新会话开场先读刚生成的交接笔记，做到「带着记忆重启」。
        // prompt 用 ASCII（Warp 经 System Events 键入，避免中文输入法问题）。
        if let handoffPath {
            let prompt = "Read .notes/\(handoffPath.lastPathComponent) — a handoff note "
                + "from the previous session — to catch up, then continue the work."
            baseCommand += " \(prompt.shellQuoted)"
        }
        let command = TerminalLauncher.buildCommand(
            workingDir: projectRoot,
            baseCommand: baseCommand,
            proxy: settings.proxyConfig,
            injectProxy: settings.injectProxyToTerminal
        )
        do {
            try TerminalLauncher().launch(
                terminal: settings.preferredTerminal,
                command: command,
                workingDir: projectRoot
            )
        } catch {
            notifications.send(subtitle: loc("Terminal launch failed"),
                               body: loc("Grant Automation permission in System Settings."))
        }

        // Step 7 / 8：关闭面板 + 成功通知。
        hooks.dismissPanel()
        if let handoffPath {
            notifications.send(subtitle: loc("Session parked"),
                               body: locf("Handoff saved to .notes/%@", handoffPath.lastPathComponent))
        } else {
            notifications.send(subtitle: loc("Parked without handoff"),
                               body: loc("Couldn't summarize. Original session archived."))
        }
    }
}
