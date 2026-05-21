import SwiftUI

/// 代理设置区块（TechSpec §07.4，V1）。
struct ProxySettingsSection: View {
    @Binding var config: ProxyConfig
    @Binding var injectToTerminal: Bool
    let onTest: () async -> TestResult
    let onModeChanged: (ProxyMode) -> Void

    @State private var httpText = ""
    @State private var socksText = ""
    @State private var httpInvalid = false
    @State private var socksInvalid = false
    @State private var isTesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Proxy")
                .font(.cdHeadline)

            Picker("Mode", selection: modeBinding) {
                Text("Auto-detect").tag(ProxyMode.autoDetect)
                Text("Manual").tag(ProxyMode.manual)
                Text("Disabled").tag(ProxyMode.disabled)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            .accessibilityLabel("Proxy mode")

            if config.mode == .manual {
                urlFields
            }

            statusRow

            Button(action: runTest) {
                HStack(spacing: Spacing.xs) {
                    if isTesting { ProgressView().controlSize(.small) }
                    Text(isTesting ? "Testing..." : "Test connection")
                }
            }
            .buttonStyle(.plain)
            .disabled(isTesting
                      || config.mode == .disabled
                      || (config.mode == .manual && (httpInvalid || httpText.isEmpty)))

            Toggle("Inject proxy to spawned terminal", isOn: $injectToTerminal)
                .font(.cdBody)
        }
        .onAppear(perform: syncFromConfig)
    }

    // MARK: Subviews

    private var urlFields: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                Text("HTTP URL:")
                    .font(.cdSubhead)
                    .frame(width: 80, alignment: .leading)
                TextField("http://127.0.0.1:7890", text: $httpText)
                    .textFieldStyle(.roundedBorder)
                    .font(.cdMono)
                    .onChange(of: httpText) { _ in validateHTTP() }
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.sm)
                            .stroke(httpInvalid ? Color.red : Color.clear, lineWidth: 1)
                    )
            }
            if httpInvalid {
                Text("Invalid URL. Use http://host:port or socks5://host:port")
                    .font(.cdFootnote)
                    .foregroundStyle(.red)
            }

            HStack(spacing: Spacing.sm) {
                Text("SOCKS URL:")
                    .font(.cdSubhead)
                    .frame(width: 80, alignment: .leading)
                TextField("(optional, e.g. socks5://127.0.0.1:7891)", text: $socksText)
                    .textFieldStyle(.roundedBorder)
                    .font(.cdMono)
                    .onChange(of: socksText) { _ in validateSOCKS() }
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.sm)
                            .stroke(socksInvalid ? Color.red : Color.clear, lineWidth: 1)
                    )
            }
        }
    }

    private var statusRow: some View {
        HStack(spacing: Spacing.xs) {
            Text("Status:")
                .font(.cdSubhead)
                .foregroundStyle(.secondary)
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.cdSubhead)
                .accessibilityValue(statusText)
        }
    }

    // MARK: Bindings & helpers

    private var modeBinding: Binding<ProxyMode> {
        Binding(
            get: { config.mode },
            set: { newMode in
                config.mode = newMode
                onModeChanged(newMode)
            }
        )
    }

    private var statusColor: Color {
        if config.mode == .disabled { return .secondary }
        switch config.lastTestStatus {
        case .reachable: return .statusHealthy
        case .apiDown: return .statusWarning
        case .notTested: return .secondary
        case .proxyNotResponding, .timeout, .dnsFailed: return .statusBloated
        }
    }

    private var statusText: String {
        if config.mode == .disabled { return "Proxy disabled" }
        var text = config.lastTestStatus.displayString
        if config.lastTestStatus == .reachable, let ms = config.lastTestLatencyMs {
            text += " in \(ms)ms"
        }
        if let at = config.lastTestedAt {
            text += " · tested \(Formatters.relativeTime(from: at))"
        }
        return text
    }

    private func runTest() {
        isTesting = true
        Task {
            _ = await onTest()
            isTesting = false
        }
    }

    private func syncFromConfig() {
        httpText = config.manualHTTPURL?.absoluteString ?? ""
        socksText = config.manualSOCKSURL?.absoluteString ?? ""
    }

    private func validateHTTP() {
        let trimmed = httpText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            httpInvalid = false
            config.manualHTTPURL = nil
        } else if ProxyConfig.isValidProxyURLString(trimmed) {
            httpInvalid = false
            config.manualHTTPURL = URL(string: trimmed)
        } else {
            httpInvalid = true
        }
    }

    private func validateSOCKS() {
        let trimmed = socksText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            socksInvalid = false
            config.manualSOCKSURL = nil
        } else if ProxyConfig.isValidProxyURLString(trimmed) {
            socksInvalid = false
            config.manualSOCKSURL = URL(string: trimmed)
        } else {
            socksInvalid = true
        }
    }
}
