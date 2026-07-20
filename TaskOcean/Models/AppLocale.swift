import Foundation

/// Central locale + localization source that follows the app's **in-app language**
/// choice (Settings → 시스템/한국어/영어), updated by `AppStore` whenever `language`
/// changes.
///
/// SwiftUI `Text("key")` already honors the `\.locale` environment (set by
/// `PreferredLanguageModifier`), but two paths do **not** and would otherwise stay
/// on the system language:
///   1. Imperative `String(localized:)` — resolves from the main bundle's system
///      localization, ignoring `\.locale`.
///   2. `DateFormatter` created with `Locale.current`.
/// Both now route through here, so the whole UI switches language live (the root
/// carries `.id(store.language)`, forcing a rebuild so imperative strings/dates
/// re-evaluate).
enum AppLocale {
    /// Locale for DateFormatters / number formatting (follows the app language).
    private(set) static var current: Locale = .autoupdatingCurrent
    /// Bundle to resolve imperative localized strings from (selected .lproj).
    private(set) static var bundle: Bundle = .main
    /// Convenience for the handful of `== "ko"` branches in formatters.
    private(set) static var isKorean: Bool =
        Locale.current.language.languageCode?.identifier == "ko"

    static func apply(_ language: LanguageOption) {
        switch language {
        case .system:
            current = .autoupdatingCurrent
            bundle = .main
        case .korean:
            current = Locale(identifier: "ko")
            bundle = lproj("ko")
        case .english:
            current = Locale(identifier: "en")
            bundle = lproj("en")
        }
        isKorean = current.language.languageCode?.identifier == "ko"
    }

    /// The `.lproj` bundle for a language code, or the main bundle if missing.
    private static func lproj(_ code: String) -> Bundle {
        Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    }

    /// Imperative localized string in the selected language.
    /// Drop-in for `String(localized: key, defaultValue: fallback)`.
    static func string(_ key: String, _ fallback: String) -> String {
        bundle.localizedString(forKey: key, value: fallback, table: nil)
    }
}
