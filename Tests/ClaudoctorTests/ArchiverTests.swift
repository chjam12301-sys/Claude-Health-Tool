import XCTest
@testable import Claudoctor

final class ArchiverTests: XCTestCase {

    private let mb: Int64 = 1_048_576

    private func makeSession(
        id: String = "uuid-1",
        sizeBytes: Int64,
        mtime: Date,
        jsonlURL: URL = URL(fileURLWithPath: "/tmp/uuid-1.jsonl"),
        dirURL: URL? = nil
    ) -> SessionInfo {
        SessionInfo(
            id: id,
            projectPath: "/tmp/project",
            projectName: "project",
            jsonlURL: jsonlURL,
            dirURL: dirURL,
            sizeBytes: sizeBytes,
            modifiedAt: mtime,
            estimatedTurns: nil
        )
    }

    // MARK: BR-006

    func testTargetFilenameFormat() {
        let archiver = Archiver(archiveDirectory: URL(fileURLWithPath: "/tmp/archive"))
        let session = makeSession(sizeBytes: mb, mtime: Date())
        let name = archiver.targetFilename(for: session, now: Date())
        let matched = name.range(of: #"^\d{8}-\d{6}-uuid-1\.jsonl$"#, options: .regularExpression)
        XCTAssertNotNil(matched, "unexpected filename: \(name)")
    }

    // MARK: BR-004

    func testShouldAutoArchiveConditions() {
        let archiver = Archiver(archiveDirectory: URL(fileURLWithPath: "/tmp/archive"))
        let now = Date()

        let oldBig = makeSession(sizeBytes: 11 * mb, mtime: now.addingTimeInterval(-60))
        XCTAssertTrue(archiver.shouldAutoArchive(oldBig, bloatedThresholdMB: 10, now: now))

        let recentBig = makeSession(sizeBytes: 11 * mb, mtime: now.addingTimeInterval(-5))
        XCTAssertFalse(archiver.shouldAutoArchive(recentBig, bloatedThresholdMB: 10, now: now))

        let oldSmall = makeSession(sizeBytes: 2 * mb, mtime: now.addingTimeInterval(-60))
        XCTAssertFalse(archiver.shouldAutoArchive(oldSmall, bloatedThresholdMB: 10, now: now))
    }

    // MARK: BR-005

    func testArchiveMovesJsonlAndCompanionDir() throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let projectDir = base.appendingPathComponent("project")
        let archiveDir = base.appendingPathComponent("archive")
        try fm.createDirectory(at: projectDir, withIntermediateDirectories: true)

        let jsonl = projectDir.appendingPathComponent("uuid-1.jsonl")
        try "line1\nline2\n".write(to: jsonl, atomically: true, encoding: .utf8)

        let companion = projectDir.appendingPathComponent("uuid-1", isDirectory: true)
        try fm.createDirectory(at: companion, withIntermediateDirectories: true)
        try "x".write(to: companion.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)

        let size = Int64((try jsonl.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        let session = makeSession(sizeBytes: size, mtime: Date(), jsonlURL: jsonl, dirURL: companion)

        let now = Date()
        let archiver = Archiver(archiveDirectory: archiveDir)
        let freed = try archiver.archive(session, now: now)

        let prefix = Archiver.timestampPrefix(now)
        XCTAssertEqual(freed, size)
        XCTAssertFalse(fm.fileExists(atPath: jsonl.path))
        XCTAssertFalse(fm.fileExists(atPath: companion.path))
        XCTAssertTrue(fm.fileExists(atPath: archiveDir.appendingPathComponent("\(prefix)-uuid-1.jsonl").path))
        XCTAssertTrue(fm.fileExists(atPath: archiveDir.appendingPathComponent("\(prefix)-uuid-1").path))

        try? fm.removeItem(at: base)
    }

    // MARK: BR-013

    func testEstimateTurns() throws {
        let fm = FileManager.default
        let file = fm.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jsonl")
        try "a\nb\nc\n".write(to: file, atomically: true, encoding: .utf8)   // 3 lines
        XCTAssertEqual(SessionScanner.estimateTurns(forFileAt: file), 2)     // ceil(3/2)
        try? fm.removeItem(at: file)
    }
}
