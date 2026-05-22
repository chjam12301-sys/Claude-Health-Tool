import SwiftUI

/// 单个 session 卡片行（UI Design v2）。点按展开操作按钮。
struct SessionRow: View {
    let session: SessionInfo
    @Binding var expandedID: String?
    let onArchive: (SessionInfo) -> Void
    let onReveal: (SessionInfo) -> Void
    var onPark: ((SessionInfo) -> Void)?

    @ObservedObject private var l10n = Localizer.shared

    private var isExpanded: Bool { expandedID == session.id }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button(action: toggle) { row }
                .buttonStyle(.plain)

            if isExpanded {
                expanded.transition(.opacity)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.creamBg)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var row: some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(session.healthStatus.color)
                .frame(width: 8, height: 8)
            ProjectIcon(name: session.projectName, tint: session.healthStatus.color, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.projectName)
                    .font(.cdBody)
                    .foregroundStyle(session.healthStatus == .healthy ? Color.textPrimary : Color.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(Formatters.relativeTime(from: session.modifiedAt, language: l10n.effective))
                    .font(.cdFootnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: Spacing.sm)
            Text(Formatters.byteString(session.sizeBytes))
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(session.healthStatus == .healthy ? Color.textPrimary : session.healthStatus.color)
        }
    }

    private var expanded: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(session.projectPath)
                .font(.cdFootnote)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: Spacing.sm) {
                if let onPark {
                    rowButton(loc("Park & Restart"), Symbols.park) { onPark(session) }
                }
                rowButton(loc("Archive"), Symbols.archive) { onArchive(session) }
                rowButton(loc("Reveal"), Symbols.reveal) { onReveal(session) }
            }
        }
        .padding(.leading, 16)
    }

    private func rowButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.cdSubhead)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(.coral)
    }

    private func toggle() {
        withAnimation(.rowExpand) {
            expandedID = isExpanded ? nil : session.id
        }
    }

    private var accessibilityLabel: String {
        "Session \(session.projectName), "
            + "size \(Formatters.byteString(session.sizeBytes)), "
            + "modified \(Formatters.relativeTime(from: session.modifiedAt)), "
            + "status \(session.healthStatus.rawValue)"
    }
}
