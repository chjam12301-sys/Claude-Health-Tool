import SwiftUI

/// 单个 session 行（TechSpec §07.1）。可展开显示操作按钮。
struct SessionRow: View {
    let session: SessionInfo
    @Binding var expandedID: String?
    let onArchive: (SessionInfo) -> Void
    let onReveal: (SessionInfo) -> Void
    var onPark: ((SessionInfo) -> Void)?

    private var isExpanded: Bool { expandedID == session.id }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Button(action: toggle) {
                header
            }
            .buttonStyle(.plain)

            if isExpanded {
                expanded
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            StatusBadge(status: session.healthStatus)
            Text(session.projectName)
                .font(.cdBody)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: Spacing.sm)
            Text("\(Formatters.byteString(session.sizeBytes)) · \(Formatters.relativeTime(from: session.modifiedAt))")
                .font(.cdSubhead)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(minHeight: 24)
    }

    private var expanded: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                if let turns = session.estimatedTurns {
                    Text("\(turns) turns ·")
                        .font(.cdFootnote)
                        .foregroundStyle(.secondary)
                }
                Text(session.projectPath)
                    .font(.cdFootnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack(spacing: Spacing.md) {
                if let onPark {
                    Button {
                        onPark(session)
                    } label: {
                        Label("Park & Restart", systemImage: Symbols.park)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Park and restart \(session.projectName)")
                }
                Button {
                    onArchive(session)
                } label: {
                    Label("Archive", systemImage: Symbols.archive)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Archive \(session.projectName)")

                Button {
                    onReveal(session)
                } label: {
                    Label("Reveal", systemImage: Symbols.reveal)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reveal \(session.projectName) in Finder")
            }
            .font(.cdBody)
            .padding(.leading, Spacing.lg)
        }
        .padding(.leading, Spacing.lg)
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
