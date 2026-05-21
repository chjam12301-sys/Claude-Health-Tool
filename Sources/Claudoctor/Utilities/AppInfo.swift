import Foundation

/// 应用常量（版本、链接）。版本号应与 Info.plist 的 CFBundleShortVersionString 保持一致。
enum AppInfo {
    static let version = "0.1.0"
    static let name = "Claudoctor"
    static let tagline = "Keeps your Claude Code sessions healthy."
    static let copyright = "© 2026 SunnyCao. MIT License."

    static let githubURL = URL(string: "https://github.com/sunnycao/claudoctor")!
    static let issuesURL = URL(string: "https://github.com/sunnycao/claudoctor/issues")!
    static let licenseURL = URL(string: "https://github.com/sunnycao/claudoctor/blob/main/LICENSE")!
    static let claudeInstallURL = URL(string: "https://claude.ai/install")!
    static let claudeDocsURL = URL(string: "https://docs.claude.com/claude-code")!
}
