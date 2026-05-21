import SwiftUI

/// Park & Restart 控件，反映 coordinator 的状态机（TechSpec §08.3，V1）。
/// 含两个动作：普通暂存重启，以及 Auto 授权（新会话跳过所有权限确认）。
struct ParkButton: View {
    @ObservedObject var coordinator: ParkAndRestartCoordinator
    var enabled: Bool = true
    var disabledReason: String?
    let onPark: () -> Void
    let onParkAuto: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Button(action: onPark) {
                HStack(spacing: Spacing.xs) {
                    if let label = coordinator.phase.label {
                        ProgressView()
                            .controlSize(.small)
                        Text(loc(label))
                    } else {
                        Image(systemName: Symbols.park)
                        Text(loc("Park & Restart"))
                    }
                }
                .font(.cdBody)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!enabled || coordinator.isRunning)
            .help(enabled ? loc("Generate a handoff note, archive this session, and start a fresh one.")
                          : (disabledReason ?? ""))

            if coordinator.phase == .idle {
                Button(action: onParkAuto) {
                    Label(loc("Auto authorize"), systemImage: "bolt.shield")
                        .font(.cdBody)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!enabled)
                .help(loc("Start the new session with all permissions pre-approved (claude --dangerously-skip-permissions)."))
            }
        }
    }
}
