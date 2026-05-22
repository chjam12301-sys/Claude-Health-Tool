import SwiftUI

/// 设计 token（Claude 原生暖色板，UI Design v2）。所有视觉常量集中于此。
enum Theme {}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Colors（§8 Claude 原生色板）

extension Color {
    // Coral 主色
    static let coral = Color(hex: 0xD97757)
    static let coralDark = Color(hex: 0xC15F3C)
    static let coralSoft = Color(hex: 0xF4D5C5)
    static let coralBg = Color(hex: 0xFBF1EA)

    // Cream 背景
    static let creamBg = Color(hex: 0xFAF9F5)
    static let creamCard = Color(hex: 0xF4F0EA)
    static let creamWarm = Color(hex: 0xEFE9DD)
    static let panelWhite = Color(hex: 0xFFFFFF)

    // 状态
    static let statusHealthy = Color(hex: 0x6B9E70)
    static let statusHealthyBg = Color(hex: 0xE8F0E5)
    static let statusWarning = Color(hex: 0xD97757)
    static let statusBloated = Color(hex: 0xC84D3A)
    static let statusBloatedBg = Color(hex: 0xFAEAE6)
    static let infoBlue = Color(hex: 0x5B7FB0)
    static let infoBg = Color(hex: 0xECF1F8)

    // 文字
    static let textPrimary = Color(hex: 0x1F1E1D)
    static let textSecondary = Color(hex: 0x6B6967)
    static let textTertiary = Color(hex: 0xA09E9B)

    // 背景别名 + 分隔线
    static let bgPrimary = Color.panelWhite
    static let bgSecondary = Color.creamBg
    static let cdBorder = Color(hex: 0x1F1E1D, alpha: 0.08)
    static let cdBorderStrong = Color(hex: 0x1F1E1D, alpha: 0.15)
}

// MARK: - Spacing（4 倍数）

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

// MARK: - Radius（4 · 8 · 12 · 14）

enum Radius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 14
}

// MARK: - Fonts

extension Font {
    static let cdHero = Font.system(size: 17, weight: .semibold)
    static let cdTitle = Font.system(size: 14, weight: .semibold)
    static let cdHeadline = Font.system(size: 13, weight: .semibold)
    static let cdBody = Font.system(size: 13, weight: .regular)
    static let cdSubhead = Font.system(size: 12, weight: .regular)
    static let cdFootnote = Font.system(size: 11, weight: .regular)
    static let cdMono = Font.system(size: 12, weight: .regular).monospacedDigit()
    static let cdStat = Font.system(size: 16, weight: .semibold).monospacedDigit()
}

// MARK: - Animation

extension Animation {
    static let statusChange = Animation.easeInOut(duration: 0.18)
    static let rowExpand = Animation.spring(response: 0.3, dampingFraction: 0.85)
    static let rowFade = Animation.easeOut(duration: 0.25)
}

// MARK: - SF Symbols

enum Symbols {
    static let menuBar = "stethoscope"
    static let archive = "archivebox"
    static let reveal = "folder"
    static let park = "bolt.fill"
    static let autoPark = "bolt.shield"
    static let settings = "gearshape"
    static let about = "info.circle"
    static let guide = "questionmark.circle"
    static let list = "list.bullet"
    static let openTerminal = "arrow.up.forward.app"
    static let proxyOK = "checkmark.shield.fill"
    static let proxyFail = "xmark.shield.fill"
    static let retest = "bolt.fill"
    static let rescan = "arrow.clockwise"
    static let statusDot = "circle.fill"
    static let bloatedDot = "exclamationmark.triangle.fill"
}
