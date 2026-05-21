import Foundation

/// 应用配置（TechSpec §04.2 / §04.3）。持久化到 UserDefaults，JSON 编码。
struct AppSettings: Codable, Equatable {
    var warningThresholdMB: Int = 5
    var bloatedThresholdMB: Int = 10
    var autoArchiveEnabled: Bool = true
    var scanIntervalMinutes: Int = 5
    var archiveDirectory: URL = AppSettings.defaultArchiveDirectory
    var preferredTerminal: TerminalApp = .auto
    var launchAtLogin: Bool = false
    var appLanguage: AppLanguage = .system

    // V1 新增
    var proxyConfig: ProxyConfig = ProxyConfig(mode: .autoDetect)
    var injectProxyToTerminal: Bool = true
    var skipPreflightOnPark: Bool = false   // 高级用户，不推荐

    // 内部 metadata
    var firstLaunchDate: Date?
    var schemaVersion: Int = AppSettings.currentSchemaVersion
    var lastNotifiedSessions: [String: Date] = [:]   // V1：去重轮次提醒

    static var defaultArchiveDirectory: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("claude-archive")
    }
}

// MARK: - 业务约束（TechSpec §04.3）

extension AppSettings {
    static let warningThresholdRange = 1...20         // MB
    static let bloatedThresholdRange = 5...50         // MB
    static let scanIntervalRange = 1...30             // minutes
    static let mandatoryGapMB = 1                     // bloated - warning >= 1

    // V1
    static let commonProxyPorts = [7890, 7891, 7993, 1080, 8080]
    static let proxyPortProbeTimeoutMs = 300
    static let proxyReachabilityTimeoutSec = 5.0
    static let proxyAutoRetestIntervalSec: TimeInterval = 300  // 每 5 分钟
    static let reachableStatusCodes: Set<Int> = [200, 401, 403]

    static let currentSchemaVersion = 2
}

// MARK: - 阈值校验与 clamp（BR-001 / BR-002 / BR-003 / BR-010）

extension AppSettings {
    /// 把所有数值字段 clamp 到合法范围，并保证 bloated >= warning + 1（BR-003）。
    /// 反序列化 + UI 设置都走这里。
    mutating func sanitize() {
        warningThresholdMB = warningThresholdMB.clamped(to: Self.warningThresholdRange)
        bloatedThresholdMB = bloatedThresholdMB.clamped(to: Self.bloatedThresholdRange)
        scanIntervalMinutes = scanIntervalMinutes.clamped(to: Self.scanIntervalRange)

        let minBloated = warningThresholdMB + Self.mandatoryGapMB
        if bloatedThresholdMB < minBloated {
            bloatedThresholdMB = min(minBloated, Self.bloatedThresholdRange.upperBound)
        }
    }

    /// 根据当前阈值推导某 size 的健康状态（BR-008）。
    func healthStatus(forSizeBytes bytes: Int64) -> HealthStatus {
        let warning = Int64(warningThresholdMB) * 1_048_576
        let bloated = Int64(bloatedThresholdMB) * 1_048_576
        if bytes >= bloated { return .bloated }
        if bytes >= warning { return .warning }
        return .healthy
    }
}

// MARK: - 持久化（BR-009）

extension AppSettings {
    static let userDefaultsKey = "com.sunnycao.claudoctor.settings"

    /// 从 UserDefaults 读取；失败 / 不存在时用默认值（CD-011），并做 schema 迁移。
    static func load(from defaults: UserDefaults = .standard) -> AppSettings {
        guard let data = defaults.data(forKey: userDefaultsKey) else {
            var fresh = AppSettings()
            fresh.firstLaunchDate = Date()
            return fresh
        }
        do {
            var decoded = try JSONDecoder().decode(AppSettings.self, from: data)
            decoded.migrateIfNeeded()
            decoded.sanitize()
            return decoded
        } catch {
            NSLog("[CD-011] Settings decode failed, using defaults: \(error.localizedDescription)")
            var fresh = AppSettings()
            fresh.firstLaunchDate = Date()
            return fresh
        }
    }

    /// 立即同步持久化（BR-009）。
    func save(to defaults: UserDefaults = .standard) {
        do {
            let data = try JSONEncoder().encode(self)
            defaults.set(data, forKey: Self.userDefaultsKey)
        } catch {
            NSLog("[CD-011] Settings encode failed: \(error.localizedDescription)")
        }
    }

    /// Schema 迁移：V0 → V1 时旧 settings 无 proxyConfig，Codable 已用默认值填充，
    /// 这里只需把 schemaVersion 升到当前值。
    private mutating func migrateIfNeeded() {
        if schemaVersion < Self.currentSchemaVersion {
            schemaVersion = Self.currentSchemaVersion
        }
    }

    /// 重置为默认值，保留 firstLaunchDate。
    func resetToDefaults() -> AppSettings {
        var fresh = AppSettings()
        fresh.firstLaunchDate = firstLaunchDate
        return fresh
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
