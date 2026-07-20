import SwiftUI

/// The app wordmark: logo glyph + "TaskOcean" set in the design's serif italic
/// (design_reference: Playfair Display italic 700). Playfair isn't bundled, so we
/// use the system serif italic substitute sanctioned by CLAUDE.md §3.
struct Wordmark: View {
    var logoHeight: CGFloat = 15
    var fontSize: CGFloat = 16
    var color: Color? = nil
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Image("TaskOceanLogo")
                .resizable()
                .scaledToFit()
                .frame(height: logoHeight)
                .foregroundStyle(color ?? theme.textPrimary)
            Text("TaskOcean")
                .font(.system(size: fontSize, weight: .bold, design: .serif))
                .italic()
                .foregroundStyle(color ?? theme.textPrimary)
                .fixedSize()
        }
    }
}
