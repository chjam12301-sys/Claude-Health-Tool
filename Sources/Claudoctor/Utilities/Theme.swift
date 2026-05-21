import SwiftUI

/// 设计 token（TechSpec §03）。所有视觉常量集中于此，改一处全局生效。
enum Theme {}

// MARK: - Colors (§03.1)

extension Color {
    static let bgPrimary = Color(nsColor: .controlBackgroundColor)
    static let bgSecondary = Color(nsColor: .windowBackgroundColor)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary

    static let statusHealthy = Color.green
    static let statusWarning = Color.orange
    static let statusBloated = Color.red
}

// MARK: - Spacing (§03.3, 8 倍数原则)

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

// MARK: - Radius (§03.4)

enum Radius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 6
    static let lg: CGFloat = 10
}

// MARK: - Fonts (§03.2)

extension Font {
    static let cdHeadline = Font.system(size: 13, weight: .medium)
    static let cdBody = Font.system(size: 13, weight: .regular)
    static let cdSubhead = Font.system(size: 12, weight: .regular)
    static let cdFootnote = Font.system(size: 11, weight: .regular)
    static let cdMono = Font.system(size: 12, weight: .regular).monospacedDigit()
}

// MARK: - Animation (§03.6)

extension Animation {
    static let statusChange = Animation.easeInOut(duration: 0.18)
    static let rowExpand = Animation.spring(response: 0.3, dampingFraction: 0.85)
    static let rowFade = Animation.easeOut(duration: 0.25)
}

// MARK: - SF Symbols (§03.5)

enum Symbols {
    static let menuBar = "stethoscope"
    static let archive = "archivebox"
    static let reveal = "folder"
    static let park = "bolt.horizontal.fill"
    static let settings = "gearshape"
    static let about = "info.circle"
    static let statusDot = "circle.fill"
    static let bloatedDot = "exclamationmark.triangle.fill"
}
