import AppKit
import SwiftUI

/// 下拉面板 P-02（UI Design v2：tab 化 + Hero + 卡片）。
struct MenuBarPanel: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject private var coordinator: ParkAndRestartCoordinator
    @ObservedObject private var l10n = Localizer.shared
    @Environment(\.openWindow) private var openWindow
    @State private var expandedID: String?
    @State private var selectedTab: PanelTab = .health

    enum PanelTab { case health, proxy }

    init(viewModel: AppViewModel) {
        _viewModel = ObservedObject(initialValue: viewModel)
        _coordinator = ObservedObject(initialValue: viewModel.parkCoordinator)
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Group {
                switch selectedTab {
                case .health: healthTab
                case .proxy: proxyTab
                }
            }
        }
        .frame(width: 280)
        .frame(height: panelHeight)
        .background(Color.panelWhite)
        .preferredColorScheme(.light)
    }

    /// 自适应屏幕可用高度，约取一半，留边距，封顶 640。
    private var panelHeight: CGFloat {
        let available = NSScreen.main?.visibleFrame.height ?? 800
        return min(max(available - 24, 460), 640)
    }

    // MARK: Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(.health, loc("Session health"))
            tabButton(.proxy, loc("Proxy status"))
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.cdBorder).frame(height: 1)
        }
    }

    private func tabButton(_ tab: PanelTab, _ title: String) -> some View {
        Button {
            withAnimation(.statusChange) { selectedTab = tab }
        } label: {
            VStack(spacing: 6) {
                Text(title)
                    .font(.cdTitle)
                    .foregroundStyle(selectedTab == tab ? Color.textPrimary : Color.textTertiary)
                Capsule()
                    .fill(selectedTab == tab ? Color.coral : Color.clear)
                    .frame(width: 32, height: 3)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    // MARK: - Health tab

    @ViewBuilder
    private var healthTab: some View {
        if viewModel.appState == .claudeNotInstalled {
            notInstalledView
            Spacer(minLength: 0)
            healthFooter
        } else if coordinator.isRunning {
            parkingView
            Spacer(minLength: 0)
            healthFooter
        } else if viewModel.sessions.isEmpty {
            emptyView
            Spacer(minLength: 0)
            healthFooter
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    statsRow
                    if let active = viewModel.activeSession {
                        sectionHeading(Symbols.park, loc("Current session"))
                        activeCard(active)
                    }
                    otherSessions
                }
                .padding(.bottom, Spacing.sm)
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
            healthFooter
        }
    }

    private var hero: some View {
        let bloated = viewModel.hasBloated
        return HStack(spacing: Spacing.sm) {
            HeroArt(tint: bloated ? .coral : .statusHealthy, size: 32)
            Text(bloated ? loc("Time to Park") : loc("Your Claude is healthy"))
                .font(.cdTitle)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    private var statsRow: some View {
        HStack(spacing: Spacing.sm) {
            StatCard(value: "\(viewModel.projectCount)", label: loc("Projects"))
            StatCard(value: largestSessionString, label: loc("Largest"),
                     emphasized: viewModel.hasBloated)
            StatCard(value: latencyValue, unit: latencyUnit, label: loc("Proxy latency"))
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.md)
    }

    private func sectionHeading(_ symbol: String, _ title: String, trailing: String? = nil) -> some View {
        HStack {
            Label {
                Text(title).font(.cdHeadline)
            } icon: {
                Image(systemName: symbol).foregroundStyle(Color.coral)
            }
            Spacer()
            if let trailing {
                Text(trailing).font(.cdSubhead).foregroundStyle(Color.coralDark)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.xs)
    }

    // MARK: Active card

    private func activeCard(_ session: SessionInfo) -> some View {
        let status = session.healthStatus
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                ProjectIcon(name: session.projectName, tint: status.color, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text(session.projectName).font(.cdTitle).lineLimit(1)
                        PillBadge(text: status.rawValue, color: status.color)
                    }
                    Text(metaLine(session))
                        .font(.cdSubhead)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            SizeProgressBar(sizeBytes: session.sizeBytes,
                            bloatedMB: viewModel.settings.bloatedThresholdMB,
                            isBloated: status != .healthy)

            HStack(spacing: Spacing.sm) {
                Button { viewModel.park(session) } label: {
                    Label(loc("Park & Restart"), systemImage: Symbols.park).font(.cdSubhead)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .tint(.coral)
                .disabled(!viewModel.claudeCLIAvailable)

                Button { viewModel.park(session, autoGrant: true) } label: {
                    Label("Auto", systemImage: Symbols.autoPark).font(.cdSubhead)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .tint(.coral)
                .disabled(!viewModel.claudeCLIAvailable)
                .help(loc("Start the new session with all permissions pre-approved (claude --dangerously-skip-permissions)."))

                Button { viewModel.revealInFinder(session) } label: {
                    Image(systemName: Symbols.reveal)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .tint(.coral)

                Spacer(minLength: 0)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(LinearGradient(
                    colors: status == .healthy
                        ? [Color.statusHealthyBg, Color(hex: 0xDEEDD9)]
                        : [Color.coralBg, Color(hex: 0xFBE6D9)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .stroke(status.color.opacity(0.18)))
        )
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.md)
    }

    // MARK: Other sessions

    private var otherSessions: some View {
        let active = viewModel.activeSession
        let others = viewModel.sessions.filter { $0.id != active?.id }
        return Group {
            if !others.isEmpty {
                sectionHeading(Symbols.list, loc("Other sessions"),
                               trailing: locf("%d total", others.count))
                VStack(spacing: Spacing.xs) {
                    ForEach(others) { session in
                        SessionRow(
                            session: session,
                            expandedID: $expandedID,
                            onArchive: { viewModel.archive($0) },
                            onReveal: { viewModel.revealInFinder($0) }
                        )
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
        }
    }

    // MARK: Parking view (Park 流程进行中)

    private var parkingView: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.md) {
                HeroArt(tint: .coral, spinning: true, size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc("Parking…")).font(.cdHero)
                    Text(loc("Generating your handoff, just a few seconds."))
                        .font(.cdSubhead).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.lg).padding(.vertical, Spacing.lg)

            parkStateCard
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)
        }
    }

    private var parkStateCard: some View {
        let step = phaseIndex(coordinator.phase)
        return VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                ProgressView().controlSize(.small)
                Text(coordinator.phase.label.map(loc) ?? loc("Parking…"))
                    .font(.cdTitle)
            }
            HStack(spacing: Spacing.xs) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Color.coral : Color.coral.opacity(0.15))
                        .frame(height: 3)
                }
            }
            HStack {
                ForEach(Array(parkStepLabels.enumerated()), id: \.offset) { i, title in
                    Text(i < step ? "✓ \(title)" : title)
                        .font(.system(size: 10))
                        .foregroundStyle(i <= step ? Color.coralDark : Color.textTertiary)
                    if i < parkStepLabels.count - 1 { Spacer() }
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(LinearGradient(colors: [Color.coralBg, Color(hex: 0xFBE6D9)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.coral.opacity(0.18)))
        )
    }

    private var parkStepLabels: [String] {
        [loc("Pre-flight"), loc("Handoff"), loc("Archive"), loc("Open terminal")]
    }

    private func phaseIndex(_ phase: ParkPhase) -> Int {
        switch phase {
        case .idle, .preflight: return 0
        case .generatingHandoff: return 1
        case .archiving: return 2
        case .openingTerminal: return 3
        }
    }

    // MARK: Empty / not installed

    private var emptyView: some View {
        VStack(spacing: Spacing.sm) {
            HeroArt(tint: .textTertiary)
            Text(loc("No sessions yet")).font(.cdTitle)
            Text(loc("Run `claude` in any project to start."))
                .font(.cdSubhead).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Link(loc("Learn more"), destination: AppInfo.claudeDocsURL)
                .font(.cdFootnote)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, Spacing.xl)
    }

    private var notInstalledView: some View {
        VStack(spacing: Spacing.sm) {
            HeroArt(tint: .textTertiary)
            Text(loc("Claude Code not detected")).font(.cdTitle)
            Text(loc("Run `claude` in any project to start."))
                .font(.cdSubhead).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Link(loc("Install Claude Code"), destination: AppInfo.claudeInstallURL)
                .font(.cdSubhead)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, Spacing.xl)
    }

    // MARK: - Proxy tab

    private enum ProxyViz { case connected, failed, neutral }

    private func proxyViz(_ config: ProxyConfig) -> ProxyViz {
        if config.mode == .disabled { return .neutral }
        switch config.lastTestStatus {
        case .reachable: return .connected
        case .notTested: return .neutral
        default: return .failed
        }
    }

    private var proxyTab: some View {
        let config = viewModel.settings.proxyConfig
        let viz = proxyViz(config)
        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                proxyHero(config: config, viz: viz)
                proxyDetailCard(config: config, viz: viz)
                if viz == .failed {
                    Text(loc("Check that Clash / Surge is running, or switch to Manual mode in Settings."))
                        .font(.cdFootnote)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color.coralBg))
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.md)
                }
                HStack(spacing: Spacing.sm) {
                    Button(action: runProxyAction) {
                        Label(config.mode == .autoDetect ? loc("Re-detect") : loc("Test now"),
                              systemImage: config.mode == .autoDetect ? Symbols.rescan : Symbols.retest)
                            .font(.cdBody).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.coral)

                    Button { openWin("settings") } label: {
                        Image(systemName: Symbols.settings).font(.cdBody)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.coral)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
            }
            Spacer(minLength: 0)
            healthFooter
        }
    }

    private func runProxyAction() {
        if viewModel.settings.proxyConfig.mode == .autoDetect {
            Task { await viewModel.runProxyAutoDetect() }
        } else {
            Task { _ = await viewModel.testConnection() }
        }
    }

    private func proxyHero(config: ProxyConfig, viz: ProxyViz) -> some View {
        let icon: String
        let iconColor: Color
        let title: String
        let colors: [Color]
        switch viz {
        case .connected:
            icon = Symbols.proxyOK; iconColor = .statusHealthy
            title = loc("Proxy connected")
            colors = [Color.infoBg, Color(hex: 0xDFE9F5)]
        case .failed:
            icon = Symbols.proxyFail; iconColor = .statusBloated
            title = loc("Proxy unreachable")
            colors = [Color.statusBloatedBg, Color(hex: 0xF8D9D2)]
        case .neutral:
            icon = "shield"; iconColor = .textTertiary
            title = config.mode == .disabled ? loc("Proxy disabled") : loc("Proxy not configured")
            colors = [Color.creamCard, Color.creamWarm]
        }
        return HStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(Color.panelWhite)
                    .frame(width: 48, height: 48)
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                Image(systemName: icon).font(.system(size: 22)).foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.cdHero).fixedSize()
                Text(proxySubtitle(config: config, viz: viz))
                    .font(.cdSubhead).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.lg)
        .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private func proxyDetailCard(config: ProxyConfig, viz: ProxyViz) -> some View {
        let autoFail = config.mode == .autoDetect && viz == .failed
        return VStack(spacing: 0) {
            detailRow(loc("Mode"), proxyModeText(config.mode))
            if autoFail {
                detailRow(loc("Tested ports"),
                          AppSettings.commonProxyPorts.map(String.init).joined(separator: " · "))
            } else {
                detailRow(loc("Proxy URL"), config.effectiveURL?.absoluteString ?? "—")
            }
            detailRow(loc("Last test"),
                      config.lastTestedAt.map { Formatters.relativeTime(from: $0, language: l10n.effective) } ?? "—")
            if viz == .failed {
                detailRow(loc("Error"), loc(config.lastTestStatus.displayString), valueColor: .statusBloated)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).fill(Color.creamBg))
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private func detailRow(_ label: String, _ value: String, valueColor: Color = .textPrimary) -> some View {
        HStack {
            Text(label).font(.cdSubhead).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.cdMono).foregroundStyle(valueColor).lineLimit(1)
        }
        .padding(.vertical, Spacing.sm)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.cdBorder).frame(height: 1) }
    }

    // MARK: - Footer

    private var healthFooter: some View {
        HStack(spacing: Spacing.sm) {
            IconButton(symbol: Symbols.settings) { openWin("settings") }

            if let active = viewModel.activeSession, viewModel.claudeCLIAvailable {
                Button { viewModel.openInTerminal(active) } label: {
                    Label(loc("Open Claude Code"), systemImage: Symbols.openTerminal)
                        .font(.cdBody)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(Color.panelWhite)
                        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Color.cdBorderStrong)))
            } else {
                Text(footerStatusText)
                    .font(.cdSubhead).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }

            Menu {
                Button(loc("How it works")) { openWin("guide") }
                Button(loc("About")) { openWin("about") }
                Divider()
                Button(loc("Quit")) { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(Color.panelWhite)
                            .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Color.cdBorder)))
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .frame(width: 34)
        }
        .padding(Spacing.md)
        .background(
            LinearGradient(colors: [Color.creamBg, Color.creamCard],
                           startPoint: .top, endPoint: .bottom)
                .overlay(alignment: .top) { Rectangle().fill(Color.cdBorder).frame(height: 1) })
    }

    // MARK: - Helpers

    private func openWin(_ id: String) {
        openWindow(id: id)
        NSApp.activate(ignoringOtherApps: true)
    }

    private var largestSessionString: String {
        guard let largest = viewModel.sessions.first?.sizeBytes else { return "—" }
        return Formatters.byteString(largest)
    }

    private var latencyValue: String {
        if viewModel.settings.proxyConfig.lastTestStatus == .reachable,
           let ms = viewModel.settings.proxyConfig.lastTestLatencyMs {
            return "\(ms)"
        }
        return "—"
    }

    private var latencyUnit: String? {
        viewModel.settings.proxyConfig.lastTestStatus == .reachable
            && viewModel.settings.proxyConfig.lastTestLatencyMs != nil ? "ms" : nil
    }

    private var footerStatusText: String {
        if viewModel.appState == .claudeNotInstalled { return loc("No projects monitored") }
        return locf("%d project(s) all clear — keep it up.", viewModel.projectCount)
    }

    private func metaLine(_ session: SessionInfo) -> String {
        var parts = [Formatters.byteString(session.sizeBytes)]
        if let turns = session.estimatedTurns { parts.append(locf("~%d turns", turns)) }
        parts.append(Formatters.relativeTime(from: session.modifiedAt, language: l10n.effective))
        return parts.joined(separator: " · ")
    }

    private func proxyModeText(_ mode: ProxyMode) -> String {
        switch mode {
        case .autoDetect: return loc("Auto-detect")
        case .manual: return loc("Manual")
        case .disabled: return loc("Disabled")
        }
    }

    private func proxySubtitle(config: ProxyConfig, viz: ProxyViz) -> String {
        switch viz {
        case .connected:
            let via = config.effectiveURL != nil ? loc("Via proxy") : loc("Direct connection")
            if let ms = config.lastTestLatencyMs { return "\(via) · \(ms)ms" }
            return via
        case .failed:
            return loc(config.lastTestStatus.displayString)
        case .neutral:
            return config.mode == .disabled ? loc("Direct connection") : loc("Not tested yet")
        }
    }
}
