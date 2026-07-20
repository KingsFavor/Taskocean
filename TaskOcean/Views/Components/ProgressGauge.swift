import SwiftUI

/// Day progress gauge (완료/전체) shown under the date header in every window
/// mode. The fill animates when progress changes and flashes + turns green on a
/// completion (celebration accent, FR request).
struct ProgressGauge: View {
    let done: Int
    let total: Int
    var height: CGFloat = 6
    var showLabel: Bool = true
    @Environment(\.theme) private var theme
    @State private var flash = false

    private var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }
    private var allDone: Bool { total > 0 && done == total }
    private var barColor: Color { allDone ? theme.syncOK : theme.textPrimary }

    var body: some View {
        HStack(spacing: 9) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.panelStrong)
                    Capsule()
                        .fill(barColor)
                        .frame(width: max(0, geo.size.width * fraction))
                        .overlay(alignment: .leading) {
                            if flash {
                                Capsule().fill(.white.opacity(0.55))
                                    .frame(width: max(0, geo.size.width * fraction))
                            }
                        }
                        .shadow(color: allDone ? theme.syncOK.opacity(flash ? 0.7 : 0) : .clear,
                                radius: 6)
                        .animation(.snappy(duration: 0.4), value: fraction)
                        .animation(.snappy(duration: 0.3), value: allDone)
                }
            }
            .frame(height: height)

            if showLabel {
                Text("\(done)/\(total)")
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(allDone ? theme.syncOK : theme.textMuted)
                    .monospacedDigit()
                    .animation(.snappy, value: allDone)
            }
        }
        .onChange(of: done) { old, new in
            guard new > old else { return }
            flash = true
            withAnimation(.easeOut(duration: 0.55)) { flash = false }
        }
    }
}
