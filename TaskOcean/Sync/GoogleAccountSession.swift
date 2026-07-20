import Foundation

/// Owns one account's OAuth credentials: Keychain persistence and access-token
/// refresh. One instance per connected account, so a revoked/expired session
/// never blocks the others (PRD §8.7).
@MainActor
final class GoogleAccountSession {
    let accountID: String              // Google `sub` — stable across email changes
    private(set) var identity: GoogleIdentity
    private var tokens: GoogleTokens
    /// Single-flight: concurrent API calls hitting an expired token must share
    /// ONE refresh request — parallel refreshes can invalidate each other when
    /// Google rotates the refresh token.
    private var refreshInFlight: Task<GoogleTokens, Error>?

    private struct Blob: Codable {
        var identity: GoogleIdentity
        var tokens: GoogleTokens
    }

    private static func key(_ accountID: String) -> String { "google.\(accountID)" }

    init(identity: GoogleIdentity, tokens: GoogleTokens) {
        self.accountID = identity.sub
        self.identity = identity
        self.tokens = tokens
        persist()
    }

    /// Restores from the Keychain on launch. `nil` → tokens were lost
    /// (keychain reset etc.) → account shows as needsReauth.
    init?(accountID: String) {
        guard let blob = KeychainStore.load(Blob.self, key: Self.key(accountID)) else { return nil }
        self.accountID = accountID
        self.identity = blob.identity
        self.tokens = blob.tokens
    }

    func validToken() async throws -> String {
        if !tokens.needsRefresh { return tokens.accessToken }
        return try await forceRefresh().accessToken
    }

    /// Also the retry path after a server-side 401 (token revoked mid-lifetime).
    @discardableResult
    func forceRefresh() async throws -> GoogleTokens {
        if let inflight = refreshInFlight { return try await inflight.value }
        let refreshToken = tokens.refreshToken
        let task = Task { try await GoogleOAuthClient.shared.refresh(refreshToken: refreshToken) }
        refreshInFlight = task
        defer { refreshInFlight = nil }
        let fresh = try await task.value
        tokens = fresh
        persist()
        return fresh
    }

    /// Re-auth completed: swap in the new grant.
    func replace(identity: GoogleIdentity, tokens: GoogleTokens) {
        self.identity = identity
        self.tokens = tokens
        persist()
    }

    /// Account removal: revoke the grant server-side (best effort), then wipe.
    func destroy() {
        GoogleOAuthClient.revoke(token: tokens.refreshToken)
        KeychainStore.delete(key: Self.key(accountID))
    }

    private func persist() {
        KeychainStore.save(Blob(identity: identity, tokens: tokens), key: Self.key(accountID))
    }
}
