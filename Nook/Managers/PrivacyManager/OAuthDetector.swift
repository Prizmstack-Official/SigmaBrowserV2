//
//  OAuthDetector.swift
//  Nook
//
//  Centralized OAuth/OIDC/SSO URL detection.
//  Used by BrowserManager (assist banner) and Tab (popup routing + completion detection).
//

import Foundation

enum OAuthDetector {

    private static let callbackSchemePatternPrefix = "scheme:"
    private static let callbackQueryParameterNames = [
        "redirect_uri",
        "redirect_url",
        "callback_url",
        "return_to",
    ]

    // MARK: - Known Provider Hosts

    /// Well-known OAuth/OIDC/SSO provider host suffixes.
    /// Matched with `host == known || host.hasSuffix(".\(known)")` to avoid
    /// false positives from substring matching (e.g. "mygithub.com" ≠ "github.com").
    static let knownProviderHosts: [String] = [
        // Google
        "accounts.google.com",
        "identitytoolkit.googleapis.com",
        "securetoken.googleapis.com",

        // Microsoft
        "login.microsoftonline.com",
        "login.live.com",
        "login.windows.net",
        "b2clogin.com",                     // Azure AD B2C custom domains

        // Apple
        "appleid.apple.com",
        "idmsa.apple.com",

        // GitHub / GitLab / Bitbucket
        "github.com",
        "gitlab.com",
        "bitbucket.org",

        // Auth0 (also *.auth0.com custom domains)
        "auth0.com",

        // Okta (also *.okta.com / *.oktapreview.com)
        "okta.com",
        "oktapreview.com",

        // OneLogin
        "onelogin.com",

        // Ping Identity
        "pingidentity.com",
        "ping.one",
        "pingone.com",
        "pingone.eu",
        "pingone.asia",
        "pingone.ca",

        // Cloudflare Access
        "cloudflareaccess.com",

        // Slack
        "slack.com",

        // Zoom
        "zoom.us",

        // Facebook / Meta
        "facebook.com",
        "m.facebook.com",

        // Amazon / AWS
        "signin.aws.amazon.com",
        "auth.aws.amazon.com",
        "amazoncognito.com",                // AWS Cognito hosted UI

        // LinkedIn
        "linkedin.com",
        "www.linkedin.com",

        // Twitter / X
        "twitter.com",
        "api.twitter.com",
        "x.com",

        // Discord
        "discord.com",

        // Twitch
        "id.twitch.tv",

        // Dropbox
        "dropbox.com",

        // Spotify
        "accounts.spotify.com",

        // Reddit
        "reddit.com",

        // Yahoo
        "login.yahoo.com",

        // WordPress.com
        "public-api.wordpress.com",

        // Salesforce
        "login.salesforce.com",
        "test.salesforce.com",

        // HubSpot
        "app.hubspot.com",

        // Box
        "account.box.com",

        // Atlassian
        "id.atlassian.com",
        "auth.atlassian.com",

        // Adobe
        "ims-na1.adobelogin.com",

        // Stripe Connect
        "connect.stripe.com",

        // Notion
        "www.notion.so",

        // Figma
        "www.figma.com",

        // Shopify
        "accounts.shopify.com",

        // Twilio / SendGrid
        "login.twilio.com",

        // GitHub Enterprise Server uses custom domains; detected by path patterns below.
        // Keycloak uses custom domains; detected by path patterns below.
        // Dex uses custom domains; detected by path patterns below.
    ]

    // MARK: - Public API

    /// Strict check: URL is very likely an OAuth/OIDC/SSO endpoint.
    ///
    /// Use this when a false positive has a visible cost (e.g. triggering the assist banner,
    /// deciding that an OAuth tab's flow has NOT completed yet).
    static func isLikelyOAuthURL(_ url: URL) -> Bool {
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()
        let query = url.query?.lowercased() ?? ""

        if matchesKnownProvider(host: host) { return true }
        if hasStrongOAuthPath(path) { return true }
        if hasOAuthQueryParams(query) { return true }

        return false
    }

    /// Broad check: URL is plausibly an OAuth/SSO popup.
    ///
    /// Use this when erring on the side of inclusion is fine (e.g. routing a popup to a
    /// temporary auth subtab even if we're occasionally wrong).
    static func isLikelyOAuthPopupURL(_ url: URL) -> Bool {
        if isLikelyOAuthURL(url) { return true }

        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()
        let query = url.query?.lowercased() ?? ""

        // Common OAuth subdomain prefixes (prefix matching is safer than substring)
        let oauthSubdomainPrefixes = ["login.", "auth.", "sso.", "oauth.", "signin.", "identity.", "id.", "account.", "accounts."]
        if oauthSubdomainPrefixes.contains(where: { host.hasPrefix($0) }) { return true }

        // Looser path signals acceptable for popup routing
        let loosePaths = ["/signin", "/login", "/callback", "/sso", "/logout"]
        if loosePaths.contains(where: { path.contains($0) }) { return true }

        // scope= is common in OAuth but also in other APIs; OK for popup detection
        if query.contains("scope=") { return true }

        return false
    }

    /// Derive a concrete callback target for popup completion.
    ///
    /// Prefer a full redirect/callback URL when the auth request declares one.
    /// If the caller only knows a callback scheme, keep a scheme-only matcher so
    /// native-app callbacks can still be recognized.
    static func oauthCompletionPattern(from authURL: URL, explicitCallbackScheme: String? = nil) -> String? {
        if let redirectURL = inferredRedirectURL(from: authURL) {
            return redirectURL.absoluteString
        }

        guard let callbackScheme = sanitizeCallbackScheme(explicitCallbackScheme) else {
            return nil
        }

        return callbackSchemePatternPrefix + callbackScheme
    }

    static func matchesOAuthCompletion(url: URL, pattern: String) -> Bool {
        if pattern.hasPrefix(callbackSchemePatternPrefix) {
            let expectedScheme = String(pattern.dropFirst(callbackSchemePatternPrefix.count))
            return url.scheme?.lowercased() == expectedScheme
        }

        guard let expectedURL = URL(string: pattern) else {
            return false
        }

        return matchesCallbackURL(url, expectedURL: expectedURL)
    }

    static func inferredRedirectURL(from authURL: URL) -> URL? {
        guard let components = URLComponents(url: authURL, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }

        for parameterName in callbackQueryParameterNames {
            guard let rawValue = queryItems.first(where: { $0.name.caseInsensitiveCompare(parameterName) == .orderedSame })?.value?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  rawValue.isEmpty == false else {
                continue
            }

            if let redirectURL = URL(string: rawValue) {
                return redirectURL
            }

            if let decodedValue = rawValue.removingPercentEncoding,
               let redirectURL = URL(string: decodedValue) {
                return redirectURL
            }
        }

        return nil
    }

    // MARK: - Helpers (internal for testing)

    static func matchesKnownProvider(host: String) -> Bool {
        for known in knownProviderHosts {
            if host == known || host.hasSuffix(".\(known)") { return true }
        }
        return false
    }

    // MARK: - Private

    /// High-confidence OAuth path patterns that indicate an auth endpoint
    /// even without matching a known provider domain.
    private static func hasStrongOAuthPath(_ path: String) -> Bool {
        let patterns = [
            "/oauth2/authorize", "/oauth/authorize",
            "/oauth2/token",     "/oauth/token",
            "/oauth2/",          "/oauth/",
            "/openid-connect/",
            "/protocol/openid-connect/",    // Keycloak
            "/realms/",                     // Keycloak realm paths
            "/connect/authorize",           // IdentityServer / Duende
            "/connect/token",
            "/saml/",  "/saml2/",
            "/.well-known/openid-configuration",
        ]
        return patterns.contains(where: { path.contains($0) })
    }

    /// Standard OAuth 2.0 / OIDC query parameters (RFC 6749).
    /// These are strong signals: non-OAuth APIs rarely use `client_id` + `redirect_uri` together.
    private static func hasOAuthQueryParams(_ query: String) -> Bool {
        let params = [
            "client_id=",
            "redirect_uri=",
            "response_type=",
            "grant_type=",
            "id_token=",
            "access_token=",
        ]
        return params.contains(where: { query.contains($0) })
    }

    private static func sanitizeCallbackScheme(_ scheme: String?) -> String? {
        guard let scheme = scheme?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              scheme.isEmpty == false else {
            return nil
        }

        return scheme
    }

    private static func matchesCallbackURL(_ currentURL: URL, expectedURL: URL) -> Bool {
        guard var currentComponents = URLComponents(url: currentURL, resolvingAgainstBaseURL: false),
              var expectedComponents = URLComponents(url: expectedURL, resolvingAgainstBaseURL: false) else {
            return false
        }

        currentComponents.scheme = currentComponents.scheme?.lowercased()
        currentComponents.host = currentComponents.host?.lowercased()
        expectedComponents.scheme = expectedComponents.scheme?.lowercased()
        expectedComponents.host = expectedComponents.host?.lowercased()

        guard currentComponents.scheme == expectedComponents.scheme,
              currentComponents.host == expectedComponents.host,
              currentComponents.port == expectedComponents.port,
              normalizedCallbackPath(currentComponents.path) == normalizedCallbackPath(expectedComponents.path) else {
            return false
        }

        let expectedQueryItems = expectedComponents.queryItems ?? []
        guard expectedQueryItems.isEmpty == false else {
            return true
        }

        let currentQueryItems = currentComponents.queryItems ?? []
        return expectedQueryItems.allSatisfy { expectedItem in
            currentQueryItems.contains {
                $0.name == expectedItem.name && $0.value == expectedItem.value
            }
        }
    }

    private static func normalizedCallbackPath(_ path: String) -> String {
        if path.isEmpty {
            return "/"
        }

        if path.count > 1, path.hasSuffix("/") {
            return String(path.dropLast())
        }

        return path
    }
}
