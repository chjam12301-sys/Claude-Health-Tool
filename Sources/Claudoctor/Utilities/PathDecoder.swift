import Foundation

/// Claude Code 项目目录路径反解码（TechSpec §04.5 / BR-020）。
///
/// Claude Code 命名规则：把绝对路径里所有 `/` 替换为 `-`。
/// 反解码：去掉开头的 `-`，剩余的 `-` 全部替换为 `/`。
/// 反解码后路径不存在时 fallback 显示原编码字符串。
enum PathDecoder {

    static func decode(
        encodedDirName: String,
        fileManager: FileManager = .default
    ) -> String {
        let trimmed = encodedDirName.hasPrefix("-")
            ? String(encodedDirName.dropFirst())
            : encodedDirName
        let candidate = "/" + trimmed.replacingOccurrences(of: "-", with: "/")
        if fileManager.fileExists(atPath: candidate) {
            return candidate
        }
        return encodedDirName    // fallback (BR-020)
    }

    /// 取路径的 basename 作为项目名。fallback 路径直接返回原串。
    static func projectName(forDecodedPath path: String) -> String {
        let name = (path as NSString).lastPathComponent
        return name.isEmpty ? path : name
    }
}
