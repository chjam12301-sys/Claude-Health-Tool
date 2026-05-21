import Foundation

/// 大小与相对时间格式化（TechSpec §07.1.6 验收口径）。
enum Formatters {

    /// `< 1 MB` 显示 "XXX KB"，`>= 1 MB` 显示 "X.X MB"。
    static func byteString(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_048_576.0
        if mb >= 1.0 {
            return String(format: "%.1f MB", mb)
        }
        let kb = Double(bytes) / 1024.0
        return "\(Int(kb.rounded())) KB"
    }

    /// `< 60s` → "Xs ago"，`< 60min` → "Xm ago"，`< 24h` → "Xh ago"，else "Xd ago"。
    /// `language` 为 `.zhHans` 时输出中文（"X秒前" 等）。
    static func relativeTime(
        from date: Date,
        now: Date = Date(),
        language: AppLanguage = .en
    ) -> String {
        let zh = (language == .zhHans)
        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 60 {
            return zh ? "\(Int(seconds))秒前" : "\(Int(seconds))s ago"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return zh ? "\(Int(minutes))分钟前" : "\(Int(minutes))m ago"
        }
        let hours = minutes / 60
        if hours < 24 {
            return zh ? "\(Int(hours))小时前" : "\(Int(hours))h ago"
        }
        let days = hours / 24
        return zh ? "\(Int(days))天前" : "\(Int(days))d ago"
    }
}
