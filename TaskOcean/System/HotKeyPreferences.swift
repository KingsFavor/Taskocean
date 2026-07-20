import Foundation
import Carbon.HIToolbox

/// User-remappable global shortcuts (FR-5.7), persisted in UserDefaults.
/// Offered as curated presets — full key-recording UI can come later.
struct HotKeyPreferences {
    enum Combo: String, CaseIterable, Identifiable {
        case optSpace          // ⌥Space
        case ctrlOptSpace      // ⌃⌥Space
        case cmdShiftSpace     // ⌘⇧Space (default capture)
        case optShiftSpace     // ⌥⇧Space (default window toggle)
        case cmdShiftT         // ⌘⇧T
        case ctrlOptT          // ⌃⌥T

        var id: String { rawValue }

        var keyCode: UInt32 {
            switch self {
            case .cmdShiftT, .ctrlOptT: return KeyCodes.t
            default: return KeyCodes.space
            }
        }

        var modifiers: UInt32 {
            switch self {
            case .optSpace:      return HotKeyModifiers.option
            case .ctrlOptSpace:  return HotKeyModifiers.control | HotKeyModifiers.option
            case .cmdShiftSpace: return HotKeyModifiers.command | HotKeyModifiers.shift
            case .optShiftSpace: return HotKeyModifiers.option | HotKeyModifiers.shift
            case .cmdShiftT:     return HotKeyModifiers.command | HotKeyModifiers.shift
            case .ctrlOptT:      return HotKeyModifiers.control | HotKeyModifiers.option
            }
        }

        var display: String {
            switch self {
            case .optSpace:      return "⌥Space"
            case .ctrlOptSpace:  return "⌃⌥Space"
            case .cmdShiftSpace: return "⌘⇧Space"
            case .optShiftSpace: return "⌥⇧Space"
            case .cmdShiftT:     return "⌘⇧T"
            case .ctrlOptT:      return "⌃⌥T"
            }
        }
    }

    private static let captureKey = "hotkey.capture"
    private static let toggleKey = "hotkey.toggleWindow"

    static var capture: Combo {
        get { UserDefaults.standard.string(forKey: captureKey).flatMap(Combo.init) ?? .cmdShiftSpace }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: captureKey) }
    }

    static var toggleWindow: Combo {
        get { UserDefaults.standard.string(forKey: toggleKey).flatMap(Combo.init) ?? .optShiftSpace }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: toggleKey) }
    }
}
