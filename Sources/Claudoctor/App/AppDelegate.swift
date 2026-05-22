import AppKit

/// 系统事件处理 + 单实例守卫（TechSpec §08.1 / BR-021 / KS-09）。
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationWillFinishLaunching(_ notification: Notification) {
        enforceSingleInstance()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let viewModel = AppViewModel.shared

        // 关闭 P-02 面板（reveal / park 后），best-effort 关闭当前 key window。
        viewModel.dismissPanel = {
            NSApp.keyWindow?.close()
        }

        // 通知点击：MenuBarExtra 无法以编程方式弹出，先把 app 带到前台。
        NotificationService.shared.onOpenPanel = {
            NSApp.activate(ignoringOtherApps: true)
        }

        viewModel.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppViewModel.shared.stop()
    }

    /// BR-021 / KS-09：检测到已有实例则弹框并退出。
    private func enforceSingleInstance() {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.sunnycao.claudoctor"
        let others = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID)
            .filter { $0 != .current }
        guard !others.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = "Claudoctor is already running"
        alert.informativeText = "Only one instance of Claudoctor can run at a time."
        alert.alertStyle = .warning
        alert.runModal()
        NSApp.terminate(nil)
    }
}
