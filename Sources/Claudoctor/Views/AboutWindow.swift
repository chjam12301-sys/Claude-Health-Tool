import SwiftUI

/// 关于窗口 P-04（TechSpec §06.4）。
struct AboutWindow: View {
    @ObservedObject private var l10n = Localizer.shared

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: Symbols.menuBar)
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
                .frame(width: 128, height: 128)

            Text(AppInfo.name)
                .font(.system(size: 24, weight: .medium))
            Text(locf("Version %@", AppInfo.version))
                .font(.cdBody)
                .foregroundStyle(.secondary)
            Text(loc(AppInfo.tagline))
                .font(.cdBody)
                .multilineTextAlignment(.center)

            HStack(spacing: Spacing.lg) {
                Link(loc("GitHub"), destination: AppInfo.githubURL)
                Link(loc("Report issue"), destination: AppInfo.issuesURL)
                Link(loc("License"), destination: AppInfo.licenseURL)
            }
            .font(.cdSubhead)

            Text(AppInfo.copyright)
                .font(.cdFootnote)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.xl)
        .frame(width: 360, height: 280)
    }
}
