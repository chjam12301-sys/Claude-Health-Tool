import AppKit
import Foundation
import ServiceManagement
import SwiftUI

/// 全局状态与服务编排（TechSpec §08 全部跨服务流程的入口）。
@MainActor
final class AppViewModel: ObservableObject {

    static let shared = AppViewModel()

    enum AppState: Equatable {
        case launching
        case ready
        case claudeNotInstalled   // CD-001：~/.claude/projects 不存在
    }

    // MARK: Published state

    @Published var settings: AppSettings {
        didSet { handleSettingsChange(old: oldValue) }
    }
    @Published private(set) var sessions: [SessionInfo] = []
    @Published private(set) var appState: AppState = .launching
    @Published private(set) var isScanning = false
    @Published private(set) var claudeCLIAvailable = false
    @Published private(set) var claudeVersion: String?
    @Published private(set) var archiveDirectoryWritable = true

    let parkCoordinator: ParkAndRestartCoordinator

    /// 关闭 P-02 面板的钩子，由 App 注入。
    var dismissPanel: (() -> Void)?

    // MARK: Services

    private let scanner = SessionScanner()
    private var watcher: FileSystemWatcher?
    private let notifications = NotificationService.shared
    private let cli = ClaudeCLI()
    private let proxyDetector = ProxyDetector()
    private let proxyTester = ProxyTester()

    // MARK: Internal

    private var scanTimer: Timer?
    private var proxyTimer: Timer?
    private var autoArchivePausedUntil: Date?
    private var started = false
    private var suppressLoginReaction = false

    init() {
        self.settings = AppSettings.load()
        self.parkCoordinator = ParkAndRestartCoordinator(
            tester: proxyTester, cli: cli, notifications: notifications)
    }

    // MARK: - F1 启动流程

    func start() {
        guard !started else { return }
        started = true

        notifications.configure()

        appState = scanner.projectsDirectoryExists ? .ready : .claudeNotInstalled

        Task { await detectCLI() }

        if scanner.projectsDirectoryExists {
            let w = FileSystemWatcher(path: SessionScanner.projectsDirectory)
            w.start { [weak self] in self?.scanNow() }
            watcher = w
        }

        validateArchiveDirectory()
        scanNow()                    // 首次扫描 + 内含自动归档（若启用）
        startProxySubsystem()

        Task { await notifications.requestPermissionIfNeeded() }

        restartScanTimer()
        restartProxyTimer()
    }

    func stop() {
        watcher?.stop()
        scanTimer?.invalidate()
        proxyTimer?.invalidate()
    }

    // MARK: - 派生状态

    /// 整体状态（BR-014：无 session 时 healthy）。
    var overallStatus: HealthStatus {
        if sessions.contains(where: { $0.healthStatus == .bloated }) { return .bloated }
        if sessions.contains(where: { $0.healthStatus == .warning }) { return .warning }
        return .healthy
    }

    var activeSession: SessionInfo? { SessionScanner.activeSession(from: sessions) }
    var bloatedCount: Int { sessions.filter { $0.healthStatus == .bloated }.count }
    var projectCount: Int { Set(sessions.map(\.projectPath)).count }
    var hasBloated: Bool { bloatedCount > 0 }

    // MARK: - 扫描（F4）

    func scanNow() {
        guard appState != .claudeNotInstalled else {
            sessions = []
            isScanning = false
            return
        }
        isScanning = true
        let scanner = self.scanner
        Task.detached(priority: .utility) { [weak self] in
            var raw = scanner.scan()
            raw.sort { $0.sizeBytes > $1.sizeBytes }
            if let idx = Self.indexOfActive(raw) {
                let turns = SessionScanner.estimateTurns(forFileAt: raw[idx].jsonlURL)
                raw[idx] = raw[idx].withEstimatedTurns(turns)
            }
            let result = raw
            await MainActor.run { self?.applyScanResult(result) }
        }
    }

    private static func indexOfActive(_ sessions: [SessionInfo]) -> Int? {
        guard !sessions.isEmpty else { return nil }
        var best = sessions.startIndex
        for i in sessions.indices where sessions[i].modifiedAt > sessions[best].modifiedAt {
            best = i
        }
        return best
    }

    private func applyScanResult(_ raw: [SessionInfo]) {
        var derived = raw
        for i in derived.indices {
            derived[i].healthStatus = settings.healthStatus(forSizeBytes: derived[i].sizeBytes)
        }
        sessions = derived
        isScanning = false

        if settings.autoArchiveEnabled { runAutoArchive() }
        checkHygiene()
    }

    /// 阈值变更后就地重算健康状态（BR-008），无需重扫。
    private func recomputeHealth() {
        for i in sessions.indices {
            sessions[i].healthStatus = settings.healthStatus(forSizeBytes: sessions[i].sizeBytes)
        }
    }

    // MARK: - F2 自动归档

    private func runAutoArchive() {
        if let until = autoArchivePausedUntil, Date() < until { return }
        autoArchivePausedUntil = nil

        let archiver = Archiver(archiveDirectory: settings.archiveDirectory)
        let targets = sessions.filter {
            archiver.shouldAutoArchive($0, bloatedThresholdMB: settings.bloatedThresholdMB)
        }
        guard !targets.isEmpty else { return }

        var freed: Int64 = 0
        var archivedIDs = Set<String>()
        for session in targets {
            do {
                freed += try archiver.archive(session)
                archivedIDs.insert(session.id)
            } catch ArchiveError.fileLocked {
                NSLog("[CD-004] Skipped locked session \(session.id)")
            } catch ArchiveError.directoryNotWritable {
                autoArchivePausedUntil = .distantFuture
                archiveDirectoryWritable = false
                notifications.send(subtitle: "Archive paused",
                                   body: "Selected archive directory is not writable.")
                break
            } catch ArchiveError.diskFull {
                autoArchivePausedUntil = Date().addingTimeInterval(3600)   // CD-009
                notifications.send(subtitle: "Archive paused",
                                   body: "Disk is full. Will retry in 1 hour.")
                break
            } catch {
                NSLog("[CD-004] Archive error \(session.id): \(error.localizedDescription)")
            }
        }

        if !archivedIDs.isEmpty {
            sessions.removeAll { archivedIDs.contains($0.id) }
            notifications.send(
                subtitle: "Archived \(archivedIDs.count) session\(archivedIDs.count == 1 ? "" : "s")",
                body: "Freed \(Formatters.byteString(freed)). Click to view.")
        }
    }

    // MARK: - 手动操作

    /// IR-04 手动归档单个 session。
    func archive(_ session: SessionInfo) {
        let archiver = Archiver(archiveDirectory: settings.archiveDirectory)
        do {
            try archiver.archive(session)
            sessions.removeAll { $0.id == session.id }
        } catch {
            notifications.send(subtitle: "Archive failed", body: error.localizedDescription)
        }
    }

    /// P-06 Archive all bloated。
    func archiveAllBloated() {
        for session in sessions.filter({ $0.healthStatus == .bloated }) {
            archive(session)
        }
    }

    /// IR-05 Reveal in Finder。
    func revealInFinder(_ session: SessionInfo) {
        NSWorkspace.shared.activateFileViewerSelecting([session.jsonlURL])
        dismissPanel?()
    }

    // MARK: - F3 Park & Restart

    func parkActiveSession() {
        guard let active = activeSession else {
            notifications.send(subtitle: "No active session",
                               body: "There's no session to park right now.")
            return
        }
        park(active)
    }

    func park(_ session: SessionInfo) {
        let hooks = ParkAndRestartCoordinator.Hooks(
            updateProxyStatus: { [weak self] result in self?.applyProxyTestResult(result) },
            sessionsChanged: { [weak self] in self?.scanNow() },
            dismissPanel: { [weak self] in self?.dismissPanel?() }
        )
        Task {
            await parkCoordinator.execute(
                session: session,
                settings: settings,
                claudeCLIAvailable: claudeCLIAvailable,
                hooks: hooks)
        }
    }

    // MARK: - CLI

    private func detectCLI() async {
        do {
            claudeVersion = try await cli.detectVersion()
            claudeCLIAvailable = true
        } catch {
            claudeVersion = nil
            claudeCLIAvailable = false
        }
    }

    // MARK: - 代理子系统（F6 / F7 / IR-10）

    private func startProxySubsystem() {
        switch settings.proxyConfig.mode {
        case .autoDetect: Task { await runProxyAutoDetect() }
        case .manual: Task { await runProxyManualTest() }
        case .disabled: break
        }
    }

    /// F6 自动探测。
    func runProxyAutoDetect() async {
        if let url = await proxyDetector.detect() {
            settings.proxyConfig.detectedURL = url
            let result = await proxyTester.test(via: url)
            applyProxyTestResult(result)
        } else {
            settings.proxyConfig.detectedURL = nil
            applyProxyTestResult(TestResult(
                status: .proxyNotResponding, httpCode: nil,
                latencyMs: nil, errorDescription: "No proxy detected"))
        }
    }

    func runProxyManualTest() async {
        let result = await proxyTester.test(via: settings.proxyConfig.effectiveURL)
        applyProxyTestResult(result)
    }

    /// IR-10 Test connection：结果即时返回给 UI。
    func testConnection() async -> TestResult {
        let result = await proxyTester.test(via: settings.proxyConfig.effectiveURL)
        applyProxyTestResult(result)
        return result
    }

    /// F7 周期重测（BR-037：不发通知）。
    private func runProxyPeriodicTest() {
        switch settings.proxyConfig.mode {
        case .disabled: return
        case .autoDetect: Task { await runProxyAutoDetect() }
        case .manual: Task { await runProxyManualTest() }
        }
    }

    private func applyProxyTestResult(_ result: TestResult) {
        var cfg = settings.proxyConfig
        cfg.lastTestStatus = result.status
        cfg.lastTestedAt = Date()
        cfg.lastTestLatencyMs = result.latencyMs
        settings.proxyConfig = cfg
    }

    // MARK: - 设置变更（F5）

    func resetSettings() {
        settings = settings.resetToDefaults()
    }

    private func handleSettingsChange(old: AppSettings) {
        settings.save()   // BR-009 立即持久化

        let new = settings
        if old.warningThresholdMB != new.warningThresholdMB
            || old.bloatedThresholdMB != new.bloatedThresholdMB {
            recomputeHealth()
        }
        if old.scanIntervalMinutes != new.scanIntervalMinutes {
            restartScanTimer()
        }
        if old.archiveDirectory != new.archiveDirectory {
            validateArchiveDirectory()
        }
        if !old.autoArchiveEnabled && new.autoArchiveEnabled {
            runAutoArchive()
        }
        if old.launchAtLogin != new.launchAtLogin && !suppressLoginReaction {
            applyLoginItem(new.launchAtLogin)
        }
        if old.proxyConfig.mode != new.proxyConfig.mode {
            handleProxyModeChange()
        } else if new.proxyConfig.mode == .manual
            && old.proxyConfig.manualHTTPURL != new.proxyConfig.manualHTTPURL {
            Task { await runProxyManualTest() }
        }
    }

    private func handleProxyModeChange() {
        switch settings.proxyConfig.mode {
        case .autoDetect:
            Task { await runProxyAutoDetect() }
        case .manual:
            Task { await runProxyManualTest() }
        case .disabled:
            var cfg = settings.proxyConfig
            cfg.lastTestStatus = .notTested
            cfg.lastTestedAt = nil
            cfg.lastTestLatencyMs = nil
            settings.proxyConfig = cfg
        }
    }

    private func validateArchiveDirectory() {
        let archiver = Archiver(archiveDirectory: settings.archiveDirectory)
        do {
            try archiver.ensureArchiveDirectory()
            archiveDirectoryWritable = true
            autoArchivePausedUntil = nil
        } catch {
            archiveDirectoryWritable = false
            autoArchivePausedUntil = .distantFuture
            notifications.send(subtitle: "Archive paused",
                               body: "Selected archive directory is not writable.")
        }
    }

    private func applyLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("[CD-013] Login item toggle failed: \(error.localizedDescription)")
            suppressLoginReaction = true
            settings.launchAtLogin = !enabled   // 回滚
            suppressLoginReaction = false
            notifications.send(subtitle: "Couldn't change login item",
                               body: error.localizedDescription)
        }
    }

    // MARK: - 卫生提醒（BR-027 / BR-028）

    private func checkHygiene() {
        let now = Date()

        // BR-028 长时间无活动
        for session in sessions {
            let stale = now.timeIntervalSince(session.modifiedAt) > 7 * 86_400
            let big = session.sizeBytes > 3 * 1_048_576
            if stale && big {
                maybeNotifyHygiene(
                    key: "stale-\(session.id)",
                    subtitle: "Idle session",
                    body: "\(session.projectName) has been idle 7+ days "
                        + "(\(Formatters.byteString(session.sizeBytes))). Consider archiving.")
            }
        }

        // BR-027 轮次提醒（活跃 session）
        if let active = activeSession, let turns = active.estimatedTurns, turns > 60 {
            maybeNotifyHygiene(
                key: "turns-\(active.id)",
                subtitle: "Long session detected",
                body: "\(active.projectName) has run 60+ turns. Consider Park & Restart.")
        }
    }

    /// 24 小时去重的卫生提醒（BR-019），去重时间持久化在 settings。
    private func maybeNotifyHygiene(key: String, subtitle: String, body: String) {
        let now = Date()
        if let last = settings.lastNotifiedSessions[key],
           now.timeIntervalSince(last) < 86_400 {
            return
        }
        settings.lastNotifiedSessions[key] = now
        notifications.send(subtitle: subtitle, body: body)
    }

    // MARK: - 定时器

    private func restartScanTimer() {
        scanTimer?.invalidate()
        let interval = TimeInterval(settings.scanIntervalMinutes * 60)
        scanTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.scanNow() }
        }
    }

    private func restartProxyTimer() {
        proxyTimer?.invalidate()
        proxyTimer = Timer.scheduledTimer(
            withTimeInterval: AppSettings.proxyAutoRetestIntervalSec, repeats: true
        ) { [weak self] _ in
            Task { @MainActor in self?.runProxyPeriodicTest() }
        }
    }
}
