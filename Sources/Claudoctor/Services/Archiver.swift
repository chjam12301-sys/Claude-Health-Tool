import Foundation

enum ArchiveError: Error, LocalizedError {
    case fileLocked            // CD-004：跳过，下次重试
    case directoryNotWritable  // CD-003：暂停自动归档
    case diskFull              // CD-009：暂停 1 小时
    case io(String)            // 其他 IO：跳过并记录

    var errorDescription: String? {
        switch self {
        case .fileLocked: return "File is locked by Claude Code"
        case .directoryNotWritable: return "Archive directory is not writable"
        case .diskFull: return "Disk is full"
        case .io(let msg): return msg
        }
    }
}

/// 归档逻辑（TechSpec §08.2 / BR-004~006 / BR-024）。
struct Archiver {
    let archiveDirectory: URL
    let fileManager: FileManager

    /// 移动正在写入的活跃 session 的保护窗口（BR-004）。
    static let mtimeGuardSeconds: TimeInterval = 30

    init(archiveDirectory: URL, fileManager: FileManager = .default) {
        self.archiveDirectory = archiveDirectory
        self.fileManager = fileManager
    }

    /// 自动归档触发条件（BR-004）：size > bloated 阈值 且 mtime ≤ now - 30s。
    func shouldAutoArchive(
        _ session: SessionInfo,
        bloatedThresholdMB: Int,
        now: Date = Date()
    ) -> Bool {
        let bloatedBytes = Int64(bloatedThresholdMB) * 1_048_576
        guard session.sizeBytes > bloatedBytes else { return false }
        return session.modifiedAt <= now.addingTimeInterval(-Self.mtimeGuardSeconds)
    }

    /// 归档目标文件名（BR-006）：`yyyyMMdd-HHmmss-{uuid}.jsonl`。
    func targetFilename(for session: SessionInfo, now: Date = Date()) -> String {
        "\(Self.timestampPrefix(now))-\(session.id).jsonl"
    }

    static func timestampPrefix(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: date)
    }

    /// 归档目录不存在时自动创建（BR-024），并校验可写（KS-03）。
    func ensureArchiveDirectory() throws {
        if !fileManager.fileExists(atPath: archiveDirectory.path) {
            do {
                try fileManager.createDirectory(
                    at: archiveDirectory, withIntermediateDirectories: true)
            } catch {
                throw Self.classify(error)
            }
        }
        guard fileManager.isWritableFile(atPath: archiveDirectory.path) else {
            throw ArchiveError.directoryNotWritable
        }
    }

    /// 归档单个 session：搬 jsonl + 同名兄弟目录（BR-005）。返回释放的字节数。
    @discardableResult
    func archive(_ session: SessionInfo, now: Date = Date()) throws -> Int64 {
        try ensureArchiveDirectory()

        let prefix = Self.timestampPrefix(now)
        let targetJSONL = archiveDirectory.appendingPathComponent("\(prefix)-\(session.id).jsonl")

        do {
            try fileManager.moveItem(at: session.jsonlURL, to: targetJSONL)
        } catch {
            throw Self.classify(error)
        }

        // 同名 UUID 目录（如存在）一起搬（BR-005）。
        if let dirURL = session.dirURL,
           fileManager.fileExists(atPath: dirURL.path) {
            let targetDir = archiveDirectory.appendingPathComponent("\(prefix)-\(session.id)")
            do {
                try fileManager.moveItem(at: dirURL, to: targetDir)
            } catch {
                // jsonl 已搬走，目录失败只记录，不回滚（容忍部分归档）。
                NSLog("[CD-004] Failed to move companion dir for \(session.id): \(error.localizedDescription)")
            }
        }

        return session.sizeBytes
    }

    /// 把 Foundation 抛出的 NSError 归类成 ArchiveError。
    private static func classify(_ error: Error) -> ArchiveError {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain {
            switch ns.code {
            case NSFileWriteOutOfSpaceError:
                return .diskFull
            case NSFileWriteNoPermissionError, NSFileWriteVolumeReadOnlyError:
                return .directoryNotWritable
            default:
                break
            }
        }
        if let posix = ns.userInfo[NSUnderlyingErrorKey] as? NSError,
           posix.domain == NSPOSIXErrorDomain {
            switch Int32(posix.code) {
            case ENOSPC: return .diskFull
            case EACCES, EROFS, EPERM: return .directoryNotWritable
            case EBUSY, ETXTBSY: return .fileLocked
            default: break
            }
        }
        return .io(error.localizedDescription)
    }
}
