import SwiftUI

/// 应用内功能介绍。
struct GuideWindow: View {
    @ObservedObject private var l10n = Localizer.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(loc("How it works"))
                    .font(.system(size: 20, weight: .semibold))

                row(icon: Symbols.menuBar,
                    title: loc("Monitor session health"),
                    body: loc("See every project's session size at a glance. Sessions over the threshold are archived to ~/claude-archive/ automatically."))

                row(icon: Symbols.park,
                    title: loc("Park & Restart"),
                    body: loc("Generate a handoff note for the current session, archive it, then open a fresh session — start over without losing context."))

                row(icon: "bolt.shield",
                    title: loc("Auto authorize"),
                    body: loc("Same as Park & Restart, but the new session starts with claude --dangerously-skip-permissions, skipping every permission prompt. Use with care."))

                row(icon: "network",
                    title: loc("Proxy"),
                    body: loc("Auto-detect or set a proxy, with a pre-flight network check before parking so a network failure never costs you a session."))
            }
            .padding(Spacing.xl)
        }
        .frame(width: 440)
        .frame(minHeight: 420, maxHeight: 560)
        .background(Color.creamBg)
        .tint(.coral)
        .preferredColorScheme(.light)
    }

    private func row(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .frame(width: 28)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title).font(.cdHeadline)
                Text(body)
                    .font(.cdSubhead)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
