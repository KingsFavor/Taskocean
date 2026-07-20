import SwiftUI

/// The circular completion control. Three looks: open ring, dashed (inbox),
/// and filled check (done) — matching the design task cards.
struct Checkbox: View {
    let isCompleted: Bool
    var dashed: Bool = false
    var size: CGFloat = 19
    var action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            ZStack {
                if isCompleted {
                    Circle().fill(theme.checkboxFill)
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.44, weight: .bold))
                        .foregroundStyle(theme.checkboxFillGlyph)
                } else {
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 1.6,
                                                   dash: dashed ? [2.5, 2.8] : []))
                        .foregroundStyle(theme.checkboxRing)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCompleted
            ? Text("a11y.markIncomplete", bundle: .main)
            : Text("a11y.markComplete", bundle: .main))
        .accessibilityAddTraits(isCompleted ? [.isSelected] : [])
    }
}
