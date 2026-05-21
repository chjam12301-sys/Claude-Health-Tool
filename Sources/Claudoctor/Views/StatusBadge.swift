import SwiftUI

/// 健康状态色点（TechSpec §07.2）。
struct StatusBadge: View {
    let status: HealthStatus
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
