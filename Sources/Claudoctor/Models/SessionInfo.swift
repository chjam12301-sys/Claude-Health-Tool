import Foundation

/// 单个 Claude Code 会话的元数据快照（TechSpec §04.1）。
/// 运行时数据，不持久化，每次扫描重建。
struct SessionInfo: Identifiable, Hashable, Equatable {
    let id: String              // jsonl 文件名去 .jsonl 后缀（uuid）
    let projectPath: String     // 反解码后的绝对路径
    let projectName: String     // basename of projectPath
    let jsonlURL: URL
    let dirURL: URL?            // 同名（同 UUID）目录，可能不存在
    let sizeBytes: Int64
    let modifiedAt: Date
    let estimatedTurns: Int?    // V1：从行数估算；未计算时为 nil

    /// 根据当前 settings 推导，由 ViewModel 注入（BR-008）。
    var healthStatus: HealthStatus = .healthy

    /// 返回带 estimatedTurns 的副本（扫描后按需补算，§ADR-006）。
    func withEstimatedTurns(_ turns: Int?) -> SessionInfo {
        SessionInfo(
            id: id,
            projectPath: projectPath,
            projectName: projectName,
            jsonlURL: jsonlURL,
            dirURL: dirURL,
            sizeBytes: sizeBytes,
            modifiedAt: modifiedAt,
            estimatedTurns: turns,
            healthStatus: healthStatus
        )
    }
}
