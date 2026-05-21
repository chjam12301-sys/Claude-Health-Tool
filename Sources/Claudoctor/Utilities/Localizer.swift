import Foundation
import SwiftUI

/// 界面语言（V1：zh-Hans + en）。
enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system
    case en
    case zhHans

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"   // 由 Localizer 翻译
        case .en: return "English"
        case .zhHans: return "中文"
        }
    }

    /// `.system` 时根据系统首选语言解析出实际语言。
    static func resolveSystem() -> AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("zh") ? .zhHans : .en
    }
}

/// 运行时本地化（自定义实现，支持即时切换，不依赖 .lproj / 重启）。
/// 翻译表以英文原文为 key，英文即为 fallback / 真值来源。
/// 仅在主线程读写（UI + 主 actor 服务），故用 `@unchecked Sendable`。
final class Localizer: ObservableObject, @unchecked Sendable {
    static let shared = Localizer()

    @Published var language: AppLanguage = .system

    private init() {}

    var effective: AppLanguage {
        language == .system ? AppLanguage.resolveSystem() : language
    }

    func string(_ key: String) -> String {
        guard effective == .zhHans else { return key }
        return Self.zhHans[key] ?? key
    }
}

/// 翻译查表。
func loc(_ key: String) -> String {
    Localizer.shared.string(key)
}

/// 带格式参数的翻译（先查表再 `String(format:)`）。
func locf(_ key: String, _ args: CVarArg...) -> String {
    String(format: Localizer.shared.string(key), arguments: args)
}

extension Localizer {
    static let zhHans: [String: String] = [
        // 通用
        "Settings": "设置",
        "About": "关于",
        "Quit": "退出",
        "Done": "完成",
        "Cancel": "取消",
        "Reset": "重置",
        "Continue": "继续",

        // 菜单栏面板
        "Claude CLI not found in PATH": "PATH 中找不到 Claude CLI",
        "%d projects · %d bloated": "%d 个项目 · %d 个臃肿",
        "Active session": "当前会话",
        "All sessions": "所有会话",
        "Archive all bloated": "归档所有臃肿会话",
        "No sessions yet": "还没有会话",
        "Run `claude` in any project to start.": "在任意项目里运行 `claude` 即可开始。",
        "Learn more": "了解更多",
        "Claude Code not detected": "未检测到 Claude Code",
        "Install Claude Code": "安装 Claude Code",
        "Auto-archive:": "自动归档：",
        "ON": "开",
        "OFF": "关",

        // 会话行
        "%d turns": "%d 轮",
        "Park & Restart": "暂存并重启",
        "Archive": "归档",
        "Reveal": "在访达中显示",

        // Park 阶段
        "Pre-flight check...": "预检中…",
        "Generating handoff...": "生成交接笔记中…",
        "Archiving...": "归档中…",
        "Opening terminal...": "打开终端中…",

        // 设置窗口
        "Thresholds": "阈值",
        "Warning": "警告",
        "Bloated": "臃肿",
        "Auto-archive": "自动归档",
        "Enable auto-archive": "启用自动归档",
        "Scan every: %d minutes": "每 %d 分钟扫描一次",
        "Archive to:": "归档到：",
        "Directory not writable": "目录不可写",
        "Terminal": "终端",
        "Preferred": "首选",
        "%@ — not installed": "%@ — 未安装",
        "Startup": "启动",
        "Launch at login": "登录时启动",
        "Advanced": "高级",
        "Skip pre-flight on Park": "暂存时跳过预检",
        "Reset to defaults": "恢复默认设置",
        "Reset all settings to defaults?": "将所有设置恢复为默认值？",
        "Skip pre-flight check?": "跳过预检？",
        "Skipping pre-flight may corrupt sessions on network failure.":
            "跳过预检可能在网络故障时损坏会话。",
        "Language": "语言",
        "System": "跟随系统",

        // 代理
        "Proxy": "代理",
        "Auto-detect": "自动检测",
        "Manual": "手动",
        "Disabled": "禁用",
        "HTTP URL:": "HTTP 地址：",
        "SOCKS URL:": "SOCKS 地址：",
        "Status:": "状态：",
        "Test connection": "测试连接",
        "Testing...": "测试中…",
        "Inject proxy to spawned terminal": "向新终端注入代理",
        "Invalid URL. Use http://host:port or socks5://host:port":
            "地址无效。请使用 http://host:port 或 socks5://host:port",
        "Proxy disabled": "代理已禁用",
        "API: Reachable (%dms)": "API：可达（%dms）",
        "API: %@": "API：%@",
        "Reachable in %dms": "可达，%dms",
        "tested %@": "检测于 %@",

        // TestStatus.displayString
        "Not tested yet": "尚未测试",
        "Reachable": "可达",
        "Proxy not responding": "代理无响应",
        "Connection timed out": "连接超时",
        "DNS resolution failed": "DNS 解析失败",
        "API returns 5xx": "API 返回 5xx",

        // 关于
        "Keeps your Claude Code sessions healthy.": "让你的 Claude Code 会话保持健康。",
        "Version %@": "版本 %@",
        "GitHub": "GitHub",
        "Report issue": "反馈问题",
        "License": "许可证",

        // 通知
        "Claude CLI not found": "找不到 Claude CLI",
        "Install Claude Code or fix your PATH.": "请安装 Claude Code 或修复 PATH。",
        "No active session": "没有活跃会话",
        "There's no session to park right now.": "当前没有可暂存的会话。",
        "Pre-flight failed": "预检失败",
        "%@. Original session preserved.": "%@。原会话已保留。",
        "Session parked": "会话已暂存",
        "Handoff saved to .notes/%@": "交接笔记已保存到 .notes/%@",
        "Parked without handoff": "已暂存（无交接笔记）",
        "Couldn't summarize. Original session archived.": "无法生成摘要，原会话已归档。",
        "Park failed": "暂存失败",
        "Couldn't archive session: %@": "无法归档会话：%@",
        "Terminal launch failed": "终端启动失败",
        "Grant Automation permission in System Settings.": "请在系统设置中授予自动化权限。",
        "Couldn't change login item": "无法修改登录项",
        "Archive paused": "自动归档已暂停",
        "Selected archive directory is not writable.": "所选归档目录不可写。",
        "Disk is full. Will retry in 1 hour.": "磁盘已满，将在 1 小时后重试。",
        "Archived %d session": "已归档 %d 个会话",
        "Archived %d sessions": "已归档 %d 个会话",
        "Freed %@. Click to view.": "释放 %@，点击查看。",
        "Archive failed": "归档失败",
        "Idle session": "闲置会话",
        "%@ has been idle 7+ days (%@). Consider archiving.":
            "%@ 已闲置 7 天以上（%@），建议归档。",
        "Long session detected": "检测到长会话",
        "%@ has run 60+ turns. Consider Park & Restart.":
            "%@ 已运行 60+ 轮，建议暂存并重启。",

        // Park 控件 + Auto 授权
        "Auto authorize": "Auto 授权",
        "Generate a handoff note, archive this session, and start a fresh one.":
            "生成交接笔记、归档当前会话，并开一个全新会话。",
        "Start the new session with all permissions pre-approved (claude --dangerously-skip-permissions).":
            "以预先批准所有权限的方式启动新会话（claude --dangerously-skip-permissions），跳过所有权限确认。",

        // 功能介绍
        "How it works": "功能介绍",
        "Monitor session health": "监控会话健康",
        "See every project's session size at a glance. Sessions over the threshold are archived to ~/claude-archive/ automatically.":
            "在菜单栏一眼看到每个项目的会话大小。超过阈值的会话会自动归档到 ~/claude-archive/。",
        "Generate a handoff note for the current session, archive it, then open a fresh session — start over without losing context.":
            "为当前会话生成交接笔记，归档原会话，再开一个全新会话——既清理上下文又不丢记忆。",
        "Same as Park & Restart, but the new session starts with claude --dangerously-skip-permissions, skipping every permission prompt. Use with care.":
            "和暂存并重启一样，但新会话用 claude --dangerously-skip-permissions 启动，跳过所有权限确认。请谨慎使用。",
        "Auto-detect or set a proxy, with a pre-flight network check before parking so a network failure never costs you a session.":
            "自动检测或手动配置代理，并在暂存前做网络预检——网络故障也不会让你丢失会话。"
    ]
}
