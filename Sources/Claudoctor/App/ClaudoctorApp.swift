import SwiftUI

@main
struct ClaudoctorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let viewModel = AppViewModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel(viewModel: viewModel)
        } label: {
            MenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings") {
            SettingsWindow(viewModel: viewModel)
        }
        .windowResizability(.contentSize)

        Window("About Claudoctor", id: "about") {
            AboutWindow()
        }
        .windowResizability(.contentSize)

        Window("Claudoctor", id: "guide") {
            GuideWindow()
        }
        .windowResizability(.contentSize)
    }
}

/// 菜单栏图标 P-01（TechSpec §06.1）：stethoscope + 状态点 overlay。
private struct MenuBarLabel: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        Image(systemName: Symbols.menuBar)
            .overlay(alignment: .bottomTrailing) { overlayDot }
    }

    @ViewBuilder
    private var overlayDot: some View {
        if viewModel.appState == .claudeNotInstalled {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 7))
                .foregroundStyle(.secondary)
        } else if viewModel.overallStatus != .healthy {
            Circle()
                .fill(viewModel.overallStatus.color)
                .frame(width: 6, height: 6)
        }
    }
}
