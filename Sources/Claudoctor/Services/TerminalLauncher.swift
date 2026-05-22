import AppKit
import Foundation

/// 启动指定终端并执行命令（TechSpec §09.4 / API-04 / BR-036 / KS-07）。
@MainActor
struct TerminalLauncher {

    enum LaunchError: Error, LocalizedError {
        case appleScriptFailed(String)   // CD-008 / KS-07
        case processFailed(String)

        var errorDescription: String? {
            switch self {
            case .appleScriptFailed(let msg): return msg
            case .processFailed(let msg): return msg
            }
        }
    }

    /// 构造 do script / -e 命令（BR-036）。
    /// `injectProxy && effectiveURL != nil` 时 prepend `export ... && `。
    static func buildCommand(
        workingDir: URL,
        baseCommand: String = "claude",
        proxy: ProxyConfig,
        injectProxy: Bool
    ) -> String {
        let prefix = injectProxy ? ProxyEnvBuilder.shellPrefix(proxy: proxy) : ""
        return "\(prefix)cd \(workingDir.path.shellQuoted) && \(baseCommand)"
    }

    /// 启动终端。`command` 应为完整 shell 命令（已含 cd / proxy 前缀）。
    func launch(terminal: TerminalApp, command: String, workingDir: URL) throws {
        let resolved = TerminalApp.resolve(terminal)
        switch resolved {
        case .terminal:
            try runAppleScript("""
            tell application "Terminal"
                do script "\(command.appleScriptEscaped)"
                activate
            end tell
            """)
        case .iterm:
            try runAppleScript("""
            tell application "iTerm"
                create window with default profile command "\(command.appleScriptEscaped)"
                activate
            end tell
            """)
        case .warp:
            // Warp 的 URL scheme 只能开标签、不能带命令，所以先在目标目录开新标签，
            // 再用 System Events 把命令键入（需要「辅助功能 Accessibility」权限）。
            let encoded = workingDir.path
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? workingDir.path
            if let url = URL(string: "warp://action/new_tab?path=\(encoded)") {
                NSWorkspace.shared.open(url)
            }
            try runAppleScript("""
            tell application "Warp" to activate
            delay 0.7
            tell application "System Events"
                keystroke "\(command.appleScriptEscaped)"
                key code 36
            end tell
            """)
        case .ghostty:
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["ghostty", "-e", command]
            process.environment = ProcessRunner.loginShellEnvironment()
            do {
                try process.run()
            } catch {
                throw LaunchError.processFailed(error.localizedDescription)
            }
        case .auto:
            // resolve 已排除 .auto，理论不可达。
            throw LaunchError.processFailed("Terminal resolution failed")
        }
    }

    private func runAppleScript(_ source: String) throws {
        var errorDict: NSDictionary?
        let script = NSAppleScript(source: source)
        script?.executeAndReturnError(&errorDict)
        if let errorDict {
            let msg = errorDict[NSAppleScript.errorMessage] as? String ?? "AppleScript error"
            NSLog("[CD-008] Terminal launch failed: \(msg)")
            throw LaunchError.appleScriptFailed(msg)
        }
    }

    /// 打开系统设置的 自动化（Automation）权限页（KS-07）。
    static func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Shell / AppleScript 转义

extension String {
    /// 单引号包裹，内部单引号用 `'\''` 转义，安全用于 shell。
    var shellQuoted: String {
        "'" + replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// 转义后可安全嵌入 AppleScript 双引号字符串字面量。
    var appleScriptEscaped: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
