import AppKit
import SwiftUI

/// 下拉面板 P-02（TechSpec §06.2）。
struct MenuBarPanel: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var expandedID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if viewModel.appState == .claudeNotInstalled {
                claudeNotInstalled
            } else {
                content
            }

            Divider()
            footer
        }
        .frame(width: 360)
        .frame(maxHeight: 600)
    }

    // MARK: Header (§06.2.4.1)

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                StatusBadge(status: viewModel.overallStatus)
                Text(AppInfo.name)
                    .font(.cdHeadline)
                Spacer()
                if viewModel.isScanning {
                    ProgressView().controlSize(.small)
                }
                Text("v\(AppInfo.version)")
                    .font(.cdFootnote)
                    .foregroundStyle(.secondary)
            }
            Text("\(viewModel.projectCount) project\(viewModel.projectCount == 1 ? "" : "s") · \(viewModel.bloatedCount) bloated")
                .font(.cdSubhead)
                .foregroundStyle(.secondary)

            proxyStatusRow

            if !viewModel.claudeCLIAvailable {
                Label("Claude CLI not found in PATH", systemImage: "exclamationmark.triangle")
                    .font(.cdFootnote)
                    .foregroundStyle(.orange)
            }
        }
        .padding(Spacing.md)
    }

    // MARK: Proxy status (mirrors P-06 top row, §06.6.4)

    private var proxyStatusRow: some View {
        let config = viewModel.settings.proxyConfig
        return HStack(spacing: Spacing.xs) {
            Circle()
                .fill(proxyColor(config))
                .frame(width: 6, height: 6)
            Text(proxyText(config))
                .font(.cdFootnote)
                .foregroundStyle(.secondary)
        }
    }

    private func proxyColor(_ config: ProxyConfig) -> Color {
        if config.mode == .disabled { return .secondary }
        switch config.lastTestStatus {
        case .reachable: return .statusHealthy
        case .apiDown: return .statusWarning
        case .notTested: return .secondary
        case .proxyNotResponding, .timeout, .dnsFailed: return .statusBloated
        }
    }

    private func proxyText(_ config: ProxyConfig) -> String {
        if config.mode == .disabled { return "Proxy disabled" }
        if config.lastTestStatus == .reachable, let ms = config.lastTestLatencyMs {
            return "API: Reachable (\(ms)ms)"
        }
        return "API: \(config.lastTestStatus.displayString)"
    }

    // MARK: Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if let active = viewModel.activeSession {
                    activeSessionCard(active)
                    Divider()
                }
                allSessionsSection
            }
            .padding(Spacing.md)
        }
    }

    // MARK: Active session card (§06.2.4.2, V1)

    private func activeSessionCard(_ session: SessionInfo) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Active session")
                .font(.cdHeadline)
                .foregroundStyle(.secondary)

            SessionRow(
                session: session,
                expandedID: $expandedID,
                onArchive: { viewModel.archive($0) },
                onReveal: { viewModel.revealInFinder($0) }
            )

            ParkButton(
                coordinator: viewModel.parkCoordinator,
                enabled: viewModel.claudeCLIAvailable,
                disabledReason: "Claude CLI not found"
            ) {
                viewModel.park(session)
            }
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(session.healthStatus == .bloated
                      ? Color.statusBloated.opacity(0.1)
                      : Color.bgSecondary.opacity(0.5))
        )
    }

    // MARK: All sessions (§06.2.4.3)

    private var allSessionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("All sessions")
                    .font(.cdHeadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if viewModel.hasBloated {
                    Button("Archive all bloated") {
                        viewModel.archiveAllBloated()
                    }
                    .buttonStyle(.plain)
                    .font(.cdFootnote)
                }
            }

            if viewModel.sessions.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.sessions) { session in
                    SessionRow(
                        session: session,
                        expandedID: $expandedID,
                        onArchive: { viewModel.archive($0) },
                        onReveal: { viewModel.revealInFinder($0) }
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: Spacing.sm) {
            Image(systemName: Symbols.menuBar)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No sessions yet")
                .font(.cdBody)
            Text("Run `claude` in any project to start.")
                .font(.cdSubhead)
                .foregroundStyle(.secondary)
            Link("Learn more", destination: AppInfo.claudeDocsURL)
                .font(.cdFootnote)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
    }

    // MARK: Claude not installed (CD-001)

    private var claudeNotInstalled: some View {
        VStack(alignment: .center, spacing: Spacing.sm) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Claude Code not detected")
                .font(.cdBody)
            Link("Install Claude Code", destination: AppInfo.claudeInstallURL)
                .font(.cdSubhead)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xl)
    }

    // MARK: Footer (§06.2.4.4)

    private var footer: some View {
        HStack {
            Text("Auto-archive: \(viewModel.settings.autoArchiveEnabled ? "ON" : "OFF") · >\(viewModel.settings.bloatedThresholdMB) MB")
                .font(.cdSubhead)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Settings") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.plain)
            Button("About") {
                openWindow(id: "about")
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.plain)
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
        }
        .font(.cdSubhead)
        .padding(Spacing.md)
    }
}
