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
    static func relativeTime(from date: Date, now: Date = Date()) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 60 {
            return "\(Int(seconds))s ago"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(Int(minutes))m ago"
        }
        let hours = minutes / 60
        if hours < 24 {
            return "\(Int(hours))h ago"
        }
        let days = hours / 24
        return "\(Int(days))d ago"
    }
}
