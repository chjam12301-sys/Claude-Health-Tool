import AppKit
import SwiftUI

/// 设置窗口 P-03（TechSpec §06.3）。
struct SettingsWindow: View {
    @ObservedObject var viewModel: AppViewModel
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
                startupSection
                advancedSection
                Divider()
                footer
            }
            .padding(Spacing.xl)
        }
        .frame(width: 480)
        .frame(minHeight: 520, maxHeight: 760)
        .alert("Reset all settings to defaults?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) { viewModel.resetSettings() }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Skip pre-flight check?", isPresented: $showSkipPreflightWarning) {
            Button("Continue", role: .destructive) {
                viewModel.settings.skipPreflightOnPark = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Skipping pre-flight may corrupt sessions on network failure.")
        }
    }

    // MARK: Thresholds (BR-001/002/003)

    private var thresholdsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Thresholds").font(.cdHeadline)
            ThresholdSlider(
                label: "Warning",
                value: settings.warningThresholdMB,
                range: AppSettings.warningThresholdRange,
                onCommit: enforceGap
            )
            ThresholdSlider(
                label: "Bloated",
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
            Text("Auto-archive").font(.cdHeadline)
            Toggle("Enable auto-archive", isOn: settings.autoArchiveEnabled)
                .font(.cdBody)
            Stepper(
                "Scan every: \(viewModel.settings.scanIntervalMinutes) minutes",
                value: settings.scanIntervalMinutes,
                in: AppSettings.scanIntervalRange
            )
            .font(.cdBody)
            HStack(spacing: Spacing.sm) {
                Text("Archive to:").font(.cdBody)
                Button(viewModel.settings.archiveDirectory.path, action: chooseArchiveDirectory)
                    .buttonStyle(.link)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if !viewModel.archiveDirectoryWritable {
                Text("Directory not writable")
                    .font(.cdFootnote)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: Terminal (V1)

    private var terminalSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Terminal").font(.cdHeadline)
            Picker("Preferred", selection: settings.preferredTerminal) {
                ForEach(TerminalApp.allCases) { terminal in
                    Text(terminal.isInstalled
                         ? terminal.displayName
                         : "\(terminal.displayName) — not installed")
                        .tag(terminal)
                }
            }
            .font(.cdBody)
        }
    }

    // MARK: Startup (V1)

    private var startupSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Startup").font(.cdHeadline)
            Toggle("Launch at login", isOn: settings.launchAtLogin)
                .font(.cdBody)
        }
    }

    // MARK: Advanced (V1)

    private var advancedSection: some View {
        DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
            Toggle("Skip pre-flight on Park", isOn: skipPreflightBinding)
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
            Button("Reset to defaults", role: .destructive) {
                showResetConfirm = true
            }
            Spacer()
            Button("Done") { dismiss() }
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
