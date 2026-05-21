import SwiftUI

/// 项目首字母方形图标（UI v2）。
struct ProjectIcon: View {
    let name: String
    var tint: Color = .coralDark
    var size: CGFloat = 36

    private var initial: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .fill(Color.panelWhite)
            .frame(width: size, height: size)
            .overlay(
                Text(initial)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(tint)
            )
            .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
    }
}

/// 统计卡片（项目监控 / 最大会话 / API 延迟）。
struct StatCard: View {
    let value: String
    var unit: String? = nil
    let label: String
    var emphasized: Bool = false

    var body: some View {
        VStack(spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.cdStat)
                    .foregroundStyle(emphasized ? Color.coralDark : Color.textPrimary)
                if let unit {
                    Text(unit)
                        .font(.cdSubhead)
                        .foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(.cdFootnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.creamBg)
        )
    }
}

/// 小色点状态徽标。
struct PillBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 1)
            .background(Capsule().fill(color))
    }
}

/// 会话大小进度条 + 刻度（0 / 警戒线 / 上限）。
struct SizeProgressBar: View {
    let sizeBytes: Int64
    let bloatedMB: Int
    let isBloated: Bool

    private var maxMB: Double { Double(bloatedMB) * 2.5 }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            GeometryReader { geo in
                let mb = Double(sizeBytes) / 1_048_576
                let frac = min(1, max(0.02, mb / maxMB))
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.textPrimary.opacity(0.06))
                    Capsule()
                        .fill(LinearGradient(
                            colors: isBloated ? [.coral, .coralDark] : [Color(hex: 0x88BD8E), .statusHealthy],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * frac)
                }
            }
            .frame(height: 6)

            HStack {
                Text("0")
                Spacer()
                Text(locf("%d MB · limit", bloatedMB))
                Spacer()
                Text("\(Int(maxMB)) MB")
            }
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
        }
    }
}

/// Claude 8 角星标志（4 根交叉胶囊 + 中心圆点）。
struct ClaudeMark: View {
    var color: Color = .white
    var dotColor: Color = .textPrimary
    var size: CGFloat = 54

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(color)
                    .frame(width: size * 0.11, height: size)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
            Circle()
                .fill(dotColor)
                .frame(width: size * 0.16, height: size * 0.16)
        }
        .frame(width: size, height: size)
    }
}

/// Hero 区圆形发光插画（Claude 8 角星）。
struct HeroArt: View {
    let tint: Color
    var spinning: Bool = false
    @State private var angle: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [tint.opacity(0.18), tint.opacity(0)],
                    center: .center, startRadius: 2, endRadius: 40))
                .frame(width: 80, height: 80)
            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: 60, height: 60)
            ClaudeMark(color: tint, dotColor: .textPrimary, size: 38)
                .rotationEffect(.degrees(spinning ? angle : 0))
        }
        .frame(width: 80, height: 80)
        .onAppear {
            guard spinning else { return }
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                angle = 360
            }
        }
    }
}

/// 面板里圆角图标按钮（footer 用）。
struct IconButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(Color.panelWhite)
                        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Color.cdBorder))
                )
        }
        .buttonStyle(.plain)
    }
}
