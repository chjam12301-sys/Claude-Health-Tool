import SwiftUI

/// 单个 session 的健康状态（TechSpec §04.1）。
enum HealthStatus: String, Codable, CaseIterable {
    case healthy
    case warning
    case bloated

    var color: Color {
        switch self {
        case .healthy: return .statusHealthy
        case .warning: return .statusWarning
        case .bloated: return .statusBloated
        }
    }

    /// 菜单栏 / 行内状态点使用的 SF Symbol。
    var symbol: String {
        switch self {
        case .bloated: return Symbols.bloatedDot
        default: return Symbols.statusDot
        }
    }
}
