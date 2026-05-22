import SwiftUI

/// 阈值调节滑块 + 数字输入（TechSpec §07.3）。
struct ThresholdSlider: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var unit: String = "MB"
    var onCommit: () -> Void = {}

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(label)
                .font(.cdBody)
                .frame(width: 84, alignment: .leading)

            TextField("", value: $value, format: .number)
                .frame(width: 44)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .onChange(of: value) { _ in
                    clampValue()
                    onCommit()
                }

            Text(unit)
                .font(.cdSubhead)
                .foregroundStyle(.secondary)

            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0.rounded()) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1,
                onEditingChanged: { editing in
                    if !editing {
                        clampValue()
                        onCommit()
                    }
                }
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value) \(unit), range \(range.lowerBound) to \(range.upperBound)")
    }

    private func clampValue() {
        let clamped = value.clamped(to: range)
        if clamped != value { value = clamped }
    }
}
