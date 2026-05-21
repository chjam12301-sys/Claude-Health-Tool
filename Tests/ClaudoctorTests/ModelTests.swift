import XCTest
@testable import Claudoctor

final class ModelTests: XCTestCase {

    // MARK: PathDecoder (BR-020)

    func testPathDecoderFallbackOnNonexistentPath() {
        let encoded = "-Users-nobody-this-does-not-exist-zzz"
        // 路径不存在 → fallback 返回原编码字符串。
        XCTAssertEqual(PathDecoder.decode(encodedDirName: encoded), encoded)
    }

    func testProjectNameFromPath() {
        XCTAssertEqual(PathDecoder.projectName(forDecodedPath: "/Users/x/talktomenote"), "talktomenote")
        XCTAssertEqual(PathDecoder.projectName(forDecodedPath: "-Users-x-fallback"), "-Users-x-fallback")
    }

    // MARK: Formatters (§07.1.6)

    func testByteStringKBvsMB() {
        XCTAssertEqual(Formatters.byteString(512 * 1024), "512 KB")
        XCTAssertEqual(Formatters.byteString(0), "0 KB")
        XCTAssertEqual(Formatters.byteString(Int64(1.5 * 1_048_576)), "1.5 MB")
        XCTAssertEqual(Formatters.byteString(21 * 1_048_576), "21.0 MB")
    }

    func testRelativeTimeBuckets() {
        let now = Date()
        XCTAssertEqual(Formatters.relativeTime(from: now.addingTimeInterval(-30), now: now), "30s ago")
        XCTAssertEqual(Formatters.relativeTime(from: now.addingTimeInterval(-90), now: now), "1m ago")
        XCTAssertEqual(Formatters.relativeTime(from: now.addingTimeInterval(-3700), now: now), "1h ago")
        XCTAssertEqual(Formatters.relativeTime(from: now.addingTimeInterval(-90_000), now: now), "1d ago")
    }

    // MARK: AppSettings (BR-001/002/003)

    func testSettingsSanitizeClampsRanges() {
        var s = AppSettings()
        s.warningThresholdMB = 0
        s.bloatedThresholdMB = 100
        s.scanIntervalMinutes = 99
        s.sanitize()
        XCTAssertEqual(s.warningThresholdMB, 1)
        XCTAssertEqual(s.bloatedThresholdMB, 50)
        XCTAssertEqual(s.scanIntervalMinutes, 30)
    }

    func testSettingsEnforcesMandatoryGap() {
        var s = AppSettings()
        s.warningThresholdMB = 10
        s.bloatedThresholdMB = 5
        s.sanitize()
        XCTAssertGreaterThanOrEqual(s.bloatedThresholdMB, s.warningThresholdMB + AppSettings.mandatoryGapMB)
    }

    func testHealthStatusDerivation() {
        let s = AppSettings()   // warning 5, bloated 10
        XCTAssertEqual(s.healthStatus(forSizeBytes: 1 * 1_048_576), .healthy)
        XCTAssertEqual(s.healthStatus(forSizeBytes: 6 * 1_048_576), .warning)
        XCTAssertEqual(s.healthStatus(forSizeBytes: 11 * 1_048_576), .bloated)
    }
}
