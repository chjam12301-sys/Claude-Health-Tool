import SwiftUI

/// 关于窗口 P-04（UI Design v2）。
struct AboutWindow: View {
    @ObservedObject private var l10n = Localizer.shared

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.coral)
                .frame(width: 96, height: 96)
                .overlay(ClaudeMark(color: .white, dotColor: .textPrimary, size: 54))
                .shadow(color: Color.coral.opacity(0.35), radius: 12, y: 8)
                .padding(.bottom, Spacing.lg)

            Text(AppInfo.name)
                .font(.system(size: 22, weight: .bold))
            Text(locf("Version %@", AppInfo.version))
                .font(.cdSubhead)
                .foregroundStyle(.secondary)

            Text(loc(AppInfo.tagline))
                .font(.cdBody)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.lg)

            HStack(spacing: Spacing.xs) {
                pillLink(loc("GitHub"), "chevron.left.forwardslash.chevron.right", AppInfo.githubURL)
                pillLink(loc("Report issue"), "ladybug", AppInfo.issuesURL)
                pillLink("MIT", "doc.text", AppInfo.licenseURL)
            }
            .padding(.top, Spacing.xl)

            Text(AppInfo.copyright)
                .font(.cdFootnote)
                .foregroundStyle(.tertiary)
                .padding(.top, Spacing.lg)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.xl)
        .frame(width: 360, height: 340)
        .background(
            LinearGradient(colors: [Color.creamBg, Color.panelWhite],
                           startPoint: .top, endPoint: .bottom))
        .preferredColorScheme(.light)
    }

    private func pillLink(_ title: String, _ symbol: String, _ url: URL) -> some View {
        Link(destination: url) {
            Label(title, systemImage: symbol)
                .font(.cdSubhead)
                .foregroundStyle(.primary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.creamBg))
        }
        .buttonStyle(.plain)
    }
}
