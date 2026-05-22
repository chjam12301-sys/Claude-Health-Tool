import Foundation
import UserNotifications

/// UserNotifications 封装（TechSpec §09.2 / §06.5 / BR-019 / BR-025）。
@MainActor
final class NotificationService: NSObject {
    static let shared = NotificationService()

    /// 单击通知时触发（打开 P-02），由 App 注入。
    var onOpenPanel: (() -> Void)?

    private var authorized = false
    private var permissionRequested = false
    private var lastSent: [String: Date] = [:]   // BR-019 去重（进程内）

    private override init() { super.init() }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// 仅首次启动请求一次权限（BR-025）。被拒后永不再请求。
    func requestPermissionIfNeeded() async {
        guard !permissionRequested else { return }
        permissionRequested = true

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            authorized = (try? await center.requestAuthorization(
                options: [.alert, .sound])) ?? false
        case .authorized, .provisional, .ephemeral:
            authorized = true
        default:
            authorized = false   // CD-014：静默
        }
    }

    /// 发送通知。未授权时静默跳过（BR-025）。
    func send(title: String = "Claudoctor",
              subtitle: String?,
              body: String,
              category: String = "default") {
        guard authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        if let subtitle { content.subtitle = subtitle }
        content.body = body
        content.categoryIdentifier = category
        content.userInfo = ["action": "open_panel"]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// 去重发送（BR-019）：同 key 在 ttl 内只发一次。
    func dedupedSend(key: String,
                     ttl: TimeInterval = 86_400,
                     subtitle: String?,
                     body: String) {
        let now = Date()
        if let last = lastSent[key], now.timeIntervalSince(last) < ttl {
            return
        }
        lastSent[key] = now
        send(subtitle: subtitle, body: body)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run { self.onOpenPanel?() }
    }
}
