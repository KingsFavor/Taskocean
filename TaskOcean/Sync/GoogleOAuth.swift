import AppKit
import AuthenticationServices
import CryptoKit
import Foundation

// MARK: - Token / identity models

/// OAuth token pair. Persisted (per account) in the Keychain only.
struct GoogleTokens: Codable {
    var accessToken: String
    var refreshToken: String
    var expiry: Date

    /// Refresh 60s early so an in-flight request never crosses the boundary.
    var needsRefresh: Bool { Date() >= expiry.addingTimeInterval(-60) }
}

/// Who signed in — decoded from the OpenID `id_token`.
struct GoogleIdentity: Codable {
    let sub: String            // stable Google account id → our Account.id
    var email: String
    var name: String?
    var hostedDomain: String?  // present for Workspace accounts

    var isWorkspace: Bool { hostedDomain != nil }
}

enum OAuthError: Error, Equatable {
    case notConfigured      // clientID missing → real backend disabled
    case cancelled          // user closed the sheet — not an error to surface
    case stateMismatch      // CSRF check failed
    case invalidCallback
    case invalidGrant       // refresh token revoked/expired → needsReauth
    case http(Int)
    case malformedResponse
}

// MARK: - OAuth client (PKCE, no client secret)

/// Google OAuth 2.0 for a native macOS app, hardened per RFC 8252:
/// - **PKCE S256** — the code is useless without the in-memory verifier.
/// - **`state` verification** — callback must echo our random state (CSRF).
/// - **No client secret** — iOS-type client; possession of the binary reveals nothing.
/// - **ASWebAuthenticationSession** — system-managed, out-of-process web flow.
///   Sandbox-safe (no loopback server, PRD §8.2) and the callback scheme needs
///   no Info.plist registration: the session intercepts the redirect itself.
@MainActor
final class GoogleOAuthClient: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GoogleOAuthClient()

    private var activeSession: ASWebAuthenticationSession?

    // MARK: Sign-in

    /// Runs the full interactive flow. `loginHint` (re-auth) pre-selects the
    /// account; without it Google shows the account chooser, which is how a
    /// second/third account gets added.
    func signIn(loginHint: String? = nil) async throws -> (GoogleIdentity, GoogleTokens) {
        guard GoogleOAuthConfig.isConfigured, let scheme = GoogleOAuthConfig.callbackScheme else {
            throw OAuthError.notConfigured
        }
        let verifier = Self.randomURLSafe(bytes: 64)
        let state = Self.randomURLSafe(bytes: 32)

        var auth = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        var items: [URLQueryItem] = [
            .init(name: "client_id", value: GoogleOAuthConfig.clientID),
            .init(name: "redirect_uri", value: GoogleOAuthConfig.redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: GoogleOAuthConfig.scopes.joined(separator: " ")),
            .init(name: "code_challenge", value: Self.s256(verifier)),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
        ]
        if let loginHint {
            items.append(.init(name: "login_hint", value: loginHint))
        } else {
            // Adding an account must never silently reuse the browser's current
            // Google session — always show the chooser.
            items.append(.init(name: "prompt", value: "select_account"))
        }
        auth.queryItems = items

        let callback = try await authenticate(url: auth.url!, callbackScheme: scheme)

        let query = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { query.first { $0.name == name }?.value }
        if let error = value("error") {
            throw error == "access_denied" ? OAuthError.cancelled : OAuthError.http(400)
        }
        guard value("state") == state else { throw OAuthError.stateMismatch }
        guard let code = value("code") else { throw OAuthError.invalidCallback }

        return try await exchange(code: code, verifier: verifier)
    }

    /// Exchanges a refresh token for a fresh access token. Google may rotate the
    /// refresh token; when it does, the new one replaces the old.
    func refresh(refreshToken: String) async throws -> GoogleTokens {
        let body = [
            "client_id": GoogleOAuthConfig.clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
        ]
        let response = try await tokenRequest(body)
        return GoogleTokens(accessToken: response.accessToken,
                            refreshToken: response.refreshToken ?? refreshToken,
                            expiry: Date().addingTimeInterval(TimeInterval(response.expiresIn)))
    }

    /// Best-effort revocation on account removal — leaves no dangling grant.
    nonisolated static func revoke(token: String) {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/revoke")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "token=\(token)".data(using: .utf8)
        URLSession.shared.dataTask(with: request).resume()
    }

    // MARK: Internals

    private func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else if let error = error as? ASWebAuthenticationSessionError,
                          error.code == .canceledLogin {
                    continuation.resume(throwing: OAuthError.cancelled)
                } else {
                    continuation.resume(throwing: error ?? OAuthError.invalidCallback)
                }
            }
            // Not ephemeral: reuse the user's signed-in Google web session so adding
            // an account is one click, not a password prompt. Multi-account is
            // handled by prompt=select_account above.
            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = self
            activeSession = session
            if !session.start() {
                continuation.resume(throwing: OAuthError.invalidCallback)
            }
        }
    }

    private struct TokenResponse: Decodable {
        let accessToken: String
        let expiresIn: Int
        let refreshToken: String?
        let idToken: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case expiresIn = "expires_in"
            case refreshToken = "refresh_token"
            case idToken = "id_token"
        }
    }

    private func exchange(code: String, verifier: String) async throws -> (GoogleIdentity, GoogleTokens) {
        let response = try await tokenRequest([
            "client_id": GoogleOAuthConfig.clientID,
            "code": code,
            "code_verifier": verifier,
            "redirect_uri": GoogleOAuthConfig.redirectURI,
            "grant_type": "authorization_code",
        ])
        guard let refreshToken = response.refreshToken,
              let idToken = response.idToken,
              let identity = Self.decodeIdentity(idToken) else {
            throw OAuthError.malformedResponse
        }
        let tokens = GoogleTokens(accessToken: response.accessToken,
                                  refreshToken: refreshToken,
                                  expiry: Date().addingTimeInterval(TimeInterval(response.expiresIn)))
        return (identity, tokens)
    }

    private func tokenRequest(_ form: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = form
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            // invalid_grant = refresh token revoked/expired → the caller flips the
            // account to needsReauth instead of retrying forever.
            if let body = String(data: data, encoding: .utf8), body.contains("invalid_grant") {
                throw OAuthError.invalidGrant
            }
            throw OAuthError.http(status)
        }
        guard let decoded = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw OAuthError.malformedResponse
        }
        return decoded
    }

    /// Decodes the JWT payload. No signature check needed: the token arrived
    /// directly from Google's token endpoint over TLS (RFC 8252 §8.11 pattern).
    private static func decodeIdentity(_ idToken: String) -> GoogleIdentity? {
        let parts = idToken.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var b64 = String(parts[1]).replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64.append("=") }
        guard let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String,
              let email = json["email"] as? String else { return nil }
        return GoogleIdentity(sub: sub, email: email,
                              name: json["name"] as? String,
                              hostedDomain: json["hd"] as? String)
    }

    private static func randomURLSafe(bytes count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes).base64URLEncoded
    }

    private static func s256(_ verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
    }

    // MARK: ASWebAuthenticationPresentationContextProviding

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            NSApp.keyWindow ?? NSApp.windows.first ?? ASPresentationAnchor()
        }
    }
}

private extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
