import SwiftUI

/// Park & Restart 按钮，反映 coordinator 的状态机（TechSpec §08.3，V1）。
struct ParkButton: View {
    @ObservedObject var coordinator: ParkAndRestartCoordinator
    var enabled: Bool = true
    var disabledReason: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
        .help(enabled ? "Generate a handoff note, archive this session, and start a fresh one"
                      : (disabledReason ?? ""))
    }
}
