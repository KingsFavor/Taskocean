import SwiftUI

/// Global quick-capture (design section 03). Spotlight-style: type + Enter to save.
/// Live natural-language date parsing shows a "내일 → 7.16 (수)" chip (FR-5.5).
/// ⌘1–9 selects the target list. Presented in a borderless panel.
struct QuickCaptureView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    var onClose: () -> Void

    @State private var draft = ""
    @State private var due: Date? = nil
    @State private var dueLoaded = false
    @FocusState private var focused: Bool

    var body: some View {
        content.provideTheme(colorScheme)
    }

    /// Default due = the day the main window is showing, until the user picks one.
    private var listBinding: Binding<String> {
        Binding(get: { store.composeTargetListID }, set: { store.composeTargetListID = $0 })
    }

    private var parsed: NaturalDateParser.Result { NaturalDateParser.parse(draft) }

    private var content: some View {
        let theme = Theme(scheme: colorScheme)
        return VStack(spacing: 0) {
            // Branded header (design: logo + serif-italic wordmark).
            HStack(spacing: 9) {
                Wordmark(logoHeight: 14, fontSize: 15)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18).padding(.top, 15).padding(.bottom, 12)
            Divider().overlay(theme.divider)

            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(theme.iconMuted)
                TextField(text: $draft) { Text("quickcapture.placeholder") }
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                    .focused($focused)
                    .onSubmit(save)
                ComposeDatePill(due: $due)
                ComposeListPill(listID: listBinding, avatarSize: 20)
            }
            .padding(.horizontal, 18).padding(.vertical, 16)

            // NLP date preview chip (design: "내일 → 7.16 (수)").
            if let token = parsed.matchedToken, let due = parsed.due {
                HStack(spacing: 7) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: "#B08363"))
                    Text(NaturalDateParser.chipText(token: token, due: due))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "#B08363"))
                    Spacer()
                }
                .padding(.horizontal, 18).padding(.bottom, 12)
            }

            Divider().overlay(theme.divider)
            HStack(spacing: 14) {
                hint("↩", "quickcapture.save", theme)
                hint("⌘↑↓", "quickcapture.list", theme)
                hint("esc", "quickcapture.cancel", theme)
                Spacer()
            }
            .padding(.horizontal, 18).padding(.vertical, 9)
        }
        .frame(width: 560)
        .background(theme.window)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme.hairline, lineWidth: 1))
        .background { listShortcuts }   // ⌘↑/⌘↓ cycle target list
        .onExitCommand(perform: onClose)
        .onAppear {
            focused = true
            if !dueLoaded { due = store.selectedDay; dueLoaded = true }
        }
    }

    /// Invisible buttons cycling the target list with ⌘↑ / ⌘↓.
    private var listShortcuts: some View {
        Group {
            Button("") { cycleList(-1) }.keyboardShortcut(.upArrow, modifiers: .command)
            Button("") { cycleList(1) }.keyboardShortcut(.downArrow, modifiers: .command)
        }
        .hidden()
    }

    private func cycleList(_ delta: Int) {
        let lists = store.lists
        guard !lists.isEmpty else { return }
        let current = lists.firstIndex { $0.id == store.composeTargetListID } ?? 0
        let next = (current + delta + lists.count) % lists.count
        store.composeTargetListID = lists[next].id
    }

    private func hint(_ key: String, _ label: LocalizedStringKey, _ theme: Theme) -> some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(theme.panel, in: RoundedRectangle(cornerRadius: 4))
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.textMuted)
        }
    }

    private func save() {
        let raw = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { onClose(); return }
        // A typed date word (NLP) wins; otherwise the date pill (default = viewed day).
        let result = NaturalDateParser.parse(raw)
        let resolved = result.matchedToken != nil ? result.due : due
        store.addTask(title: result.title, due: resolved.map(CalendarSupport.startOfDay))
        draft = ""
        onClose()
    }
}
