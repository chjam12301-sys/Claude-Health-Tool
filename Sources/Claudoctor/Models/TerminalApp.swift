import AppKit

/// 终端偏好（TechSpec §04.2 / D-11）。
enum TerminalApp: String, Codable, CaseIterable, Identifiable {
    case auto
    case terminal
    case iterm
    case warp
    case ghostty

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto-detect"
        case .terminal: return "Terminal"
        case .iterm: return "iTerm"
        case .warp: return "Warp"
        case .ghostty: return "Ghostty"
        }
    }

    var bundleId: String? {
        switch self {
        case .auto: return nil
        case .terminal: return "com.apple.Terminal"
        case .iterm: return "com.googlecode.iterm2"
        case .warp: return "dev.warp.Warp-Stable"
        case .ghostty: return "com.mitchellh.ghostty"
        }
    }

    /// 该终端是否已安装。`.auto` 永远视为可用。
    var isInstalled: Bool {
        guard let bundleId else { return true }
        return NSWorkspace.shared
            .urlForApplication(withBundleIdentifier: bundleId) != nil
    }

    /// Auto-detect 优先级（D-11）：Ghostty > Warp > iTerm > Terminal.app。
    static let autoDetectOrder: [TerminalApp] = [.ghostty, .warp, .iterm, .terminal]

    /// 解析实际要启动的终端：`.auto` 时按优先级取第一个已安装的，
    /// 全部未安装则 fallback 到 Terminal.app（系统自带，必存在）。
    static func resolve(_ preferred: TerminalApp) -> TerminalApp {
        guard preferred == .auto else { return preferred }
        return autoDetectOrder.first(where: { $0.isInstalled }) ?? .terminal
    }
}
