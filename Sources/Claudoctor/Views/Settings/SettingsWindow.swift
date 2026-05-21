import AppKit
import SwiftUI

/// 设置窗口 P-03（TechSpec §06.3）。
struct SettingsWindow: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject private var l10n = Localizer.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showResetConfirm = false
    @State private var showAdvanced = false
    @State private var showSkipPreflightWarning = false

    private var settings: Binding<AppSettings> { $viewModel.settings }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                thresholdsSection
                autoArchiveSection
                ProxySettingsSection(
                    config: settings.proxyConfig,
                    injectToTerminal: settings.injectProxyToTerminal,
                    onTest: { await viewModel.testConnection() },
                    onModeChanged: { _ in }   // 变更由 settings.didSet 统一处理（F5）
                )
                terminalSection
                languageSection
                startupSection
                advancedSection
                Divider()
                footer
            }
            .padding(Spacing.xl)
        }
        .frame(width: 480)
        .frame(minHeight: 520, maxHeight: 760)
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

    // MARK: Language (V1)

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(loc("Language")).font(.cdHeadline)
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

    // MARK: Thresholds (BR-001/002/003)

    private var thresholdsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(loc("Thresholds")).font(.cdHeadline)
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

    // MARK: Terminal (V1)

    private var terminalSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(loc("Terminal")).font(.cdHeadline)
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

    // MARK: Startup (V1)

    private var startupSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(loc("Startup")).font(.cdHeadline)
            Toggle(loc("Launch at login"), isOn: settings.launchAtLogin)
                .font(.cdBody)
        }
    }

    // MARK: Advanced (V1)

    private var advancedSection: some View {
        DisclosureGroup(loc("Advanced"), isExpanded: $showAdvanced) {
            Toggle(loc("Skip pre-flight on Park"), isOn: skipPreflightBinding)
                .font(.cdBody)
                .padding(.top, Spacing.xs)
        }
        .font(.cdHeadline)
    }

    private var skipPreflightBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.skipPreflightOnPark },
            set: { newValue in
                if newValue {
                    showSkipPreflightWarning = true   // 确认后才真正生效
                } else {
                    viewModel.settings.skipPreflightOnPark = false
                }
            }
        )
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Button(loc("Reset to defaults"), role: .destructive) {
                showResetConfirm = true
            }
            Spacer()
            Button(loc("Done")) { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
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
