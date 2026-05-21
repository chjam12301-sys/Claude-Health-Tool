import Foundation

/// 扫描 `~/.claude/projects/` 重建 session 列表（TechSpec §08.2 / BR-011 / BR-012）。
///
/// 性能约束：只用 stat（resourceValues），不打开 jsonl 内容（BR-012）。
/// estimatedTurns 在需要时单独按需计算（§ADR-006）。
struct SessionScanner {

    /// Claude Code 数据源根目录（只读）。
    static var projectsDirectory: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
            .appendingPathComponent("projects")
    }

    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// `~/.claude/projects/` 是否存在（CD-001）。
    var projectsDirectoryExists: Bool {
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(
            atPath: Self.projectsDirectory.path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }

    /// 执行一次完整扫描。仅 stat，不读文件内容。
    func scan() -> [SessionInfo] {
        let root = Self.projectsDirectory
        guard projectsDirectoryExists else { return [] }

        let projectDirs = (try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var sessions: [SessionInfo] = []
        for projectDir in projectDirs {
            guard isDirectory(projectDir) else { continue }
            sessions.append(contentsOf: scanProject(projectDir))
        }
        return sessions
    }

    private func scanProject(_ projectDir: URL) -> [SessionInfo] {
        let encodedName = projectDir.lastPathComponent
        let decodedPath = PathDecoder.decode(encodedDirName: encodedName)
        let projectName = PathDecoder.projectName(forDecodedPath: decodedPath)

        let entries = (try? fileManager.contentsOfDirectory(
            at: projectDir,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        let jsonlFiles = entries.filter { $0.pathExtension == "jsonl" }

        return jsonlFiles.compactMap { jsonlURL -> SessionInfo? in
            guard let values = try? jsonlURL.resourceValues(
                forKeys: [.fileSizeKey, .contentModificationDateKey]),
                let size = values.fileSize,
                let mtime = values.contentModificationDate
            else { return nil }

            let uuid = jsonlURL.deletingPathExtension().lastPathComponent
            let siblingDir = projectDir.appendingPathComponent(uuid, isDirectory: true)
            let dirURL = isDirectory(siblingDir) ? siblingDir : nil

            return SessionInfo(
                id: uuid,
                projectPath: decodedPath,
                projectName: projectName,
                jsonlURL: jsonlURL,
                dirURL: dirURL,
                sizeBytes: Int64(size),
                modifiedAt: mtime,
                estimatedTurns: nil
            )
        }
    }

    /// 全局活跃 session = mtime 最新的 jsonl（BR-007）。
    static func activeSession(from sessions: [SessionInfo]) -> SessionInfo? {
        sessions.max(by: { $0.modifiedAt < $1.modifiedAt })
    }

    /// 估算轮次：文件总行数 / 2 向上取整（BR-013）。流式读取，避免大文件占内存。
    static func estimateTurns(forFileAt url: URL) -> Int? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var lineCount = 0
        let newline = UInt8(0x0A)
        while autoreleasepool(invoking: { () -> Bool in
            guard let chunk = try? handle.read(upToCount: 64 * 1024), !chunk.isEmpty else {
                return false
            }
            for byte in chunk where byte == newline { lineCount += 1 }
            return true
        }) {}

        return Int((Double(lineCount) / 2.0).rounded(.up))
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }
}
