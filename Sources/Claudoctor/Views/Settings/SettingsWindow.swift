import AppKit
import SwiftUI

/// 设置窗口 P-03（UI Design v2：左侧栏导航）。
struct SettingsWindow: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject private var l10n = Localizer.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPane: SettingsPane = .thresholds
    @State private var showResetConfirm = false
    @State private var showSkipPreflightWarning = false

    private var settings: Binding<AppSettings> { $viewModel.settings }

    enum SettingsPane: CaseIterable {
        case thresholds, autoArchive, proxy, terminal, startup, language, advanced

        var title: String {
            switch self {
            case .thresholds: return "Thresholds"
            case .autoArchive: return "Auto-archive"
            case .proxy: return "Proxy"
            case .terminal: return "Terminal"
            case .startup: return "Startup"
            case .language: return "Language"
            case .advanced: return "Advanced"
            }
        }

        var icon: String {
            switch self {
            case .thresholds: return "slider.horizontal.3"
            case .autoArchive: return "archivebox"
            case .proxy: return "shield"
            case .terminal: return "terminal"
            case .startup: return "power"
            case .language: return "globe"
            case .advanced: return "wrench.and.screwdriver"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebar
                Divider()
                ScrollView {
                    content
                        .padding(Spacing.xl)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.panelWhite)
            }
            Divider()
            footer
        }
        .frame(width: 640, height: 560)
        .tint(.coral)
        .preferredColorScheme(.light)
        .alert(loc("Reset all settings to defaults?"), isPresented: $showResetConfirm) {
            Button(loc("Reset"), role: .destructive) { viewModel.resetSettings() }
            Button(loc("Cancel"), role: .cancel) {}
        }
        .alert(loc("Skip pre-flight check?"), isPresented: $showSkipPreflightWarning) {
            Button(loc("Continue"), role: .destructive) {
                viewModel.settings.skipPreflightOnPark = true
            }
            Button(loc("Cancel"), role: .cancel) {}
        } message: {
            Text(loc("Skipping pre-flight may corrupt sessions on network failure."))
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsPane.allCases, id: \.self) { pane in
                sidebarItem(pane)
            }
            Spacer()
        }
        .padding(Spacing.sm)
        .frame(width: 168)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.creamBg)
    }

    private func sidebarItem(_ pane: SettingsPane) -> some View {
        let selected = selectedPane == pane
        return Button {
            selectedPane = pane
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: pane.icon).frame(width: 16)
                Text(loc(pane.title)).font(.cdBody)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .foregroundStyle(selected ? Color.white : Color.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(selected ? Color.coral : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Content panes

    @ViewBuilder
    private var content: some View {
        switch selectedPane {
        case .thresholds: thresholdsSection
        case .autoArchive: autoArchiveSection
        case .proxy:
            ProxySettingsSection(
                config: settings.proxyConfig,
                injectToTerminal: settings.injectProxyToTerminal,
                onTest: { await viewModel.testConnection() },
                onModeChanged: { _ in }
            )
        case .terminal: terminalSection
        case .startup: startupSection
        case .language: languageSection
        case .advanced: advancedSection
        }
    }

    // MARK: Thresholds (BR-001/002/003)

    private var thresholdsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(loc("Thresholds")).font(.cdHeadline)
            SettingsCard {
                ThresholdSlider(
                    label: loc("Warning"),
                    value: settings.warningThresholdMB,
                    range: AppSettings.warningThresholdRange,
                    onCommit: enforceGap
                )
                ThresholdSlider(
                    label: loc("Bloated"),
                    value: settings.bloatedThresholdMB,
                    range: AppSettings.bloatedThresholdRange,
                    onCommit: enforceGap
                )
            }
        }
    }

    private func enforceGap() {
        let minBloated = viewModel.settings.warningThresholdMB + AppSettings.mandatoryGapMB
        if viewModel.settings.bloatedThresholdMB < minBloated {
            viewModel.settings.bloatedThresholdMB =
                min(minBloated, AppSettings.bloatedThresholdRange.upperBound)
        }
    }

    // MARK: Auto-archive

    private var autoArchiveSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(loc("Auto-archive")).font(.cdHeadline)
            SettingsCard {
                Toggle(loc("Enable auto-archive"), isOn: settings.autoArchiveEnabled)
                    .font(.cdBody)
                Stepper(
                    locf("Scan every: %d minutes", viewModel.settings.scanIntervalMinutes),
                    value: settings.scanIntervalMinutes,
                    in: AppSettings.scanIntervalRange
                )
                .font(.cdBody)
                HStack(spacing: Spacing.sm) {
                    Text(loc("Archive to:")).font(.cdBody)
                    Button(viewModel.settings.archiveDirectory.path, action: chooseArchiveDirectory)
                        .buttonStyle(.link)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if !viewModel.archiveDirectoryWritable {
                    Text(loc("Directory not writable"))
                        .font(.cdFootnote)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: Terminal

    private var terminalSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(loc("Terminal")).font(.cdHeadline)
            SettingsCard {
                Picker(loc("Preferred"), selection: settings.preferredTerminal) {
                    ForEach(TerminalApp.allCases) { terminal in
                        Text(terminal.isInstalled
                             ? terminal.displayName
                             : locf("%@ — not installed", terminal.displayName))
                            .tag(terminal)
                    }
                }
                .font(.cdBody)
            }
        }
    }

    // MARK: Startup

    private var startupSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(loc("Startup")).font(.cdHeadline)
            SettingsCard {
                Toggle(loc("Launch at login"), isOn: settings.launchAtLogin)
                    .font(.cdBody)
            }
        }
    }

    // MARK: Language

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(loc("Language")).font(.cdHeadline)
            SettingsCard {
                Picker(loc("Language"), selection: settings.appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language == .system ? loc("System") : language.displayName)
                            .tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .font(.cdBody)
            }
        }
    }

    // MARK: Advanced

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(loc("Advanced")).font(.cdHeadline)
            SettingsCard {
                Toggle(loc("Skip pre-flight on Park"), isOn: skipPreflightBinding)
                    .font(.cdBody)
            }
        }
    }

    private var skipPreflightBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.skipPreflightOnPark },
            set: { newValue in
                if newValue {
                    showSkipPreflightWarning = true
                } else {
                    viewModel.settings.skipPreflightOnPark = false
                }
            }
        )
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Label(loc("Reset to defaults"), systemImage: "arrow.counterclockwise")
                    .font(.cdSubhead)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.statusBloated)

            Spacer()

            Button(loc("Done")) { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(.coral)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.md)
        .background(Color.creamCard)
    }

    private func chooseArchiveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = viewModel.settings.archiveDirectory
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.settings.archiveDirectory = url
        }
    }
}
