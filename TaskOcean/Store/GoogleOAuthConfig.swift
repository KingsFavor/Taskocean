import Foundation

/// Google OAuth client configuration (PKCE, custom-scheme redirect).
///
/// Fill `clientID` with the **iOS-type** OAuth client issued for bundle id
/// `com.dws.taskocean` (setup guide: docs/oauth_setup.md). Everything else is
/// derived. While `clientID` is empty the app runs on `MockTaskRepository`.
///
/// PRD refs: §8.2 (PKCE + custom scheme, NO loopback server — sandbox),
///           §8.7 (per-account session isolation).
enum GoogleOAuthConfig {
    /// Google Cloud OAuth 2.0 client ID — iOS application type (macOS native +
    /// custom-scheme redirect is exactly the flow that type exists for; the
    /// "Desktop app" type presumes a loopback redirect, which the sandbox forbids).
    static let clientID = "895270857661-evvk8aj1lka3rcebl00tv8m6ud0kdq20.apps.googleusercontent.com"

    /// Google requires iOS-type clients to redirect to the *reversed client id*
    /// scheme. Derived, so filling `clientID` is the only manual step.
    /// "123-abc.apps.googleusercontent.com" → "com.googleusercontent.apps.123-abc"
    /// No Info.plist registration needed: ASWebAuthenticationSession intercepts
    /// the redirect itself (the `taskocean://` scheme in Info.plist is unrelated).
    static var callbackScheme: String? {
        let suffix = ".apps.googleusercontent.com"
        guard clientID.hasSuffix(suffix), clientID.count > suffix.count else { return nil }
        return "com.googleusercontent.apps." + clientID.dropLast(suffix.count)
    }

    static var redirectURI: String { (callbackScheme ?? "taskocean") + ":/oauthredirect" }

    /// `tasks` = full read/write (PRD §8.2). openid/email/profile feed the
    /// account chip (name, email, workspace-vs-personal) via the id_token —
    /// no extra userinfo call.
    static let scopes = ["openid", "email", "profile",
                         "https://www.googleapis.com/auth/tasks"]

    static var isConfigured: Bool { callbackScheme != nil }
}
